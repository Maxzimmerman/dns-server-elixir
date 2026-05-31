# Working with binaries and DNS in Elixir

A study guide for the remaining stages of the codecrafters DNS server challenge:
parse header, parse question, parse compressed packet, forwarding server.

The next stages are about **reading bytes back out of a packet** instead of writing
them, so the key skill is pattern-matching on binaries.

---

## 1. Binaries vs. bitstrings

Every value between `<<` and `>>` is a **bitstring** — a sequence of bits. When that
sequence is a multiple of 8 bits, it's also a **binary** (a byte string). UDP and
most other I/O require binaries — they refuse bitstrings.

```elixir
<<0, 1, 2>>           # 24 bits = binary
<<1::4>>              # 4 bits, NOT a binary
<<1::4, 0::4>>        # 8 bits = binary
```

The errors `"Bad value on output port"` and `"is not a multiple of the unit"` both
mean the same thing: you tried to use a bitstring where a binary was required. Fix
= make the total bit count divisible by 8.

---

## 2. Segment syntax

A segment inside `<<...>>` looks like:

```
value::size-unit-type-endianness-signedness
```

You rarely need all of those. The relevant modifiers for DNS:

| Modifier | Meaning | Default |
| --- | --- | --- |
| `::N` | size — **N bits** if integer, **N bytes** if binary | 8 (integer) / all (binary) |
| `-big` / `-little` | byte order | `big` |
| `-integer` / `-binary` / `-bitstring` | how to interpret the value | inferred |
| `-signed` / `-unsigned` | signedness | `unsigned` |

Two gotchas:

- **For integers, `::N` is BITS.** `1::16` is 16 bits = 2 bytes. `1::4` is 4 bits.
- **For binaries, `::N` is BYTES.** `"io"::binary-size(2)` is 2 bytes.

Memorize this table — every DNS field is one of these:

| You want | Write |
| --- | --- |
| 1 byte int | `value` or `value::8` |
| 2 byte int | `value::16` |
| 4 byte int | `value::32` |
| N bytes raw | `binary::binary-size(n)` |
| The rest | `rest::binary` |

---

## 3. Building vs. parsing — same syntax, different direction

This is the unlock for the rest of the challenge.

**Building** — `<<...>>` on the right, you supply values:

```elixir
header = <<1234::16, 0x8000::16, 1::16, 1::16, 0::16, 0::16>>
```

**Parsing** — `<<...>>` on the left, Elixir fills variables in:

```elixir
<<id::16, flags::16, qdcount::16, ancount::16, nscount::16, arcount::16, rest::binary>> = packet
```

### Parsing techniques

**Assert a literal:**
```elixir
<<0x1234::16, qr::1, _opcode::4, _::11, _qdcount::16, _rest::binary>> = packet
# Crashes immediately if id is not 0x1234.
```

**Consume some bytes, keep the rest:**
```elixir
<<consumed::32, rest::binary>> = packet
```

**Recurse to parse variable-length structures (like labels):**
```elixir
def parse_labels(<<0, rest::binary>>, acc), do: {Enum.reverse(acc), rest}
def parse_labels(<<len, label::binary-size(len), rest::binary>>, acc),
  do: parse_labels(rest, [label | acc])
```

Pattern: each match either consumes a chunk and recurses, or hits a terminator and
returns.

---

## 4. The DNS packet, byte by byte

### Header — always 12 bytes

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      ID  (16 bits)                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|QR|  OPCODE   |AA|TC|RD|RA|   Z    |   RCODE   |
+--+-----------+--+--+--+--+--------+-----------+
|                     QDCOUNT  (16 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     ANCOUNT  (16 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     NSCOUNT  (16 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     ARCOUNT  (16 bits)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

Parse template:
```elixir
<<id::16,
  qr::1, opcode::4, aa::1, tc::1, rd::1, ra::1, z::3, rcode::4,
  qdcount::16, ancount::16, nscount::16, arcount::16,
  rest::binary>> = packet
```

One pattern unpacks the entire header.

### Question — variable length

```
NAME   (variable, label sequence ending in 0x00)
TYPE   (16 bits)
CLASS  (16 bits)
```

`codecrafters.io` → `0c 63 6f 64 65 63 72 61 66 74 65 72 73  02 69 6f  00`
— 17 bytes for the name, then 2+2 for type/class.

### Answer

```
NAME       (label sequence or compression pointer)
TYPE       (16 bits)
CLASS      (16 bits)
TTL        (32 bits)
RDLENGTH   (16 bits) — length of RDATA in bytes
RDATA      (RDLENGTH bytes)
```

---

## 5. Compression pointers

To save space, anywhere a label could appear, you may see two bytes whose top two
bits are both 1 — that's a **pointer** instead of a `<len><bytes>` label:

```
 1 1 P P P P P P  P P P P P P P P
 \_/ \____ 14-bit offset ____/
  pointer flag
```

So a byte starting with `11xxxxxx` (i.e. `>= 0xC0`) is not a length — it's the
start of a 2-byte pointer. The lower 14 bits give a byte offset from the start of
the packet to jump to.

Parser decision rule:

```elixir
def parse_name(<<0b11::2, offset::14, rest::binary>>, full_packet) do
  # pointer — jump to that offset in full_packet, continue from there
end
def parse_name(<<0, rest::binary>>, _), do: {[], rest}   # end of name
def parse_name(<<len, label::binary-size(len), rest::binary>>, full_packet) do
  # ordinary label, recurse
end
```

Key insight: to follow a pointer you need the **whole original packet** in scope,
not just the remaining tail. Carry `full_packet` alongside the cursor.

---

## 6. Reading error messages

### "construction of binary failed... not a multiple of the unit"
**Cause:** total bit count in your `<<...>>` isn't divisible by 8.
**Look at:** the segment Elixir prints at the end (e.g. `2::size(2)`) is the prime
suspect — usually `::N` where you meant `::N*8`.

### "no match of right hand side value"
**Cause:** your pattern doesn't fit the data.
**Look at:** print `byte_size(data)` and the first ~20 bytes. Compare against your
pattern.

When pattern-matching variable-length binaries, **always end with `rest::binary`**.
Without it Elixir requires the binary to be exactly the size of your fixed fields.

### "Bad value on output port 'udp_inet'"
**Cause:** `:gen_udp.send` got a bitstring or non-binary.
**Fix:** make sure your response is a whole number of bytes.

---

## 7. Debugging toolbox

### In code

```elixir
IO.inspect(data, label: "incoming", limit: :infinity)
IO.inspect(data, base: :hex, label: "hex")
byte_size(data)        # how many bytes
bit_size(data)         # how many bits (when suspecting bit misalignment)
```

### iex sanity checks

```bash
iex -S mix
```

```elixir
iex> <<1::16>>
<<0, 1>>
iex> <<id::16, rest::binary>> = <<4, 210, 1, 2, 3>>
iex> id
1234
iex> rest
<<1, 2, 3>>
```

Before writing a complicated pattern in your code, type it into `iex` against a
sample binary first.

### On the wire

```bash
dig @127.0.0.1 -p 2053 +noedns codecrafters.io.
```

`+noedns` matters — without it, `dig` adds an OPT record in the additional section
that you don't handle yet.

To see what a real DNS server sends:

```bash
dig @8.8.8.8 codecrafters.io. +yaml
# or
sudo tcpdump -X -i lo0 'udp port 53'
```

Comparing your server's bytes against a real server's is the fastest way to spot
mistakes.

---

## 8. A useful refactor for the next stages

Today's `loop/1` builds the response from hardcoded helpers. The next stages need
you to *parse* `data` and produce a response that depends on it. Plan to introduce:

```elixir
def handle(packet) do
  query = parse(packet)
  reply = build_reply(query)
  encode(reply)
end
```

Where:
- `parse/1` turns bytes into a struct (id, opcode, rd, name, type, class…)
- `build_reply/1` constructs a response struct (same id, qr=1, copy question, add answer)
- `encode/1` serializes the struct back into bytes

The existing `Message` struct is the right shape. Splitting parse/build/encode
keeps each stage's change small.

---

## 9. Quick reference

```elixir
# Build
<<n::8>>           # 1 byte
<<n::16>>          # 2 bytes big-endian
<<n::32>>          # 4 bytes big-endian
<<"label">>        # ASCII bytes of the string
<<a::1, b::7>>     # bit fields (combined into 1 byte)

# Parse
<<n::8, rest::binary>>           = bin   # take 1 byte
<<n::16, rest::binary>>          = bin   # take 2 bytes
<<chunk::binary-size(5), rest::binary>> = bin   # take 5 raw bytes
<<flag::1, opcode::4, _::11, rest::binary>> = bin   # bit fields

# Inspect
IO.inspect(bin, base: :hex)
byte_size(bin)
bit_size(bin)

# Concatenate
binary1 <> binary2
```

The single biggest leap is going from *building* binaries to *parsing* them. Once
`<<id::16, rest::binary>> = packet` feels natural, the rest of the stages are
mostly "which fields, in what order."
