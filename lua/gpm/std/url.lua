-- --[[
--     MIT License

--     Copyright (c) 2024 Pika Software

--     Permission is hereby granted, free of charge, to any person obtaining a copy
--     of this software and associated documentation files (the "Software"), to deal
--     in the Software without restriction, including without limitation the rights
--     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--     copies of the Software, and to permit persons to whom the Software is
--     furnished to do so, subject to the following conditions:

--     The above copyright notice and this permission notice shall be included in all
--     copies or substantial portions of the Software.

--     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--     SOFTWARE.
-- --]]
-- import type, tostring, tonumber, rawget, rawset, getmetatable, pairs from _G
-- import byte, char, sub, gsub, lower, format from string
-- import rshift, lshift, band, bor from (bit or bit32)
-- import concat, remove from table
-- import floor from math

-- -- a quirky way to check if number have metatable
-- -- if it has, then we can use getmetatable and have even faster isnumber function
-- local isstring
-- if stringMeta := getmetatable("")
--     isstring = (v) -> getmetatable(v) == stringMeta

-- local isnumber
-- if numberMeta := getmetatable(0)
--     isnumber = (v) -> getmetatable(v) == numberMeta

-- -- Garry's Mod have is<type> functions, prefer them because they are faster than type
-- isstring = isstring or (v) -> type(v) == "string"
-- istable = istable or (v) -> type(v) == "table"
-- isnumber = isnumber or (v) -> type(v) == "number"

-- compileCharacterTable = (chars) ->
--     result = []
--     for v in *chars
--         if istable v
--             for i = byte(v[1]), byte(v[2])
--                 result[i] = true
--         else
--             result[byte(v)] = true
--     return result

-- -- Use result from `compileCharacterTable` in `containsCharacter` as chars
-- containsCharacter = (str, chars, startPos = 1, endPos = #str) ->
--     for i = startPos, endPos
--         if chars[byte(str, i)]
--             return true
--     return false

-- PUNYCODE_PREFIX = [0x78, 0x6E, 0x2D, 0x2D] -- xn--

-- SPECIAL_SCHEMAS =
--     ftp: 21
--     file: true -- currently if value is true, then scheme will be treated as file: scheme in the parser
--     http: 80
--     https: 443
--     ws: 80
--     wss: 443

-- FORBIDDEN_HOST_CODE_POINTS = compileCharacterTable [
--     "\0", "\t", "\n", "\r"
--     " ", "#", "/", ":"
--     "<", ">", "?", "@"
--     "[", "\\", "]", "^", "|"
-- ]

-- FORBIDDEN_DOMAIN_CODE_POINTS = compileCharacterTable [
--     "\0", "\t", "\n", "\r"
--     " ", "#", "/", ":"
--     "<", ">", "?", "@"
--     "[", "\\", "]", "^", "|"
--     ["\0", "\x1F"], "%", "\x7F"
-- ]

-- FILE_OTHERWISE_CODE_POINTS = compileCharacterTable [ "/", "\\", "?", "#" ]

-- DECODE_LOOKUP_TABLE = []
-- for i = 0x00, 0xFF
--     hex = bit.tohex(i, 2)
--     DECODE_LOOKUP_TABLE[hex] = char(i)
--     DECODE_LOOKUP_TABLE[hex\upper!] = char(i)

-- URI_DECODE_SET = {...DECODE_LOOKUP_TABLE}
-- for i in *[0x2D, 0x2E, 0x21, 0x7E, 0x2A, 0x27, 0x28, 0x29] -- decodeURI doesn't decode these characters: ; / ? : @ & = + $ , #
--     hex = bit.tohex(i, 2)
--     URI_DECODE_SET[hex] = nil
--     URI_DECODE_SET[hex\upper!] = nil

-- percentDecode = (s, decodeSet) ->
--     s = gsub(s, "%%(%x%x)", decodeSet)
--     return s

-- compilePercentEncodeSet = (encodeSet, ...) ->
--     -- Lookup table for decoding percent-encoded characters and encoding special characters
--     -- Using HEX_TABLE will result in a double speedup compared to using functions
--     encodeSet = {...encodeSet} -- copy given encodeSet, so we don't modify it
--     for ch in *{...}
--         if isstring ch
--             ch = byte(ch) -- if string then convert to byte

--         if isnumber ch -- just a single character
--             encodeSet[char(ch)] = "%" .. bit.tohex(ch, 2)\upper!
--         elseif istable ch -- range of characters
--             charStart = isstring(ch[1]) and byte(ch[1]) or ch[1]
--             charEnd = isstring(ch[2]) and byte(ch[2]) or ch[2]

--             for i = charStart, charEnd
--                 encodeSet[char(i)] = "%" .. bit.tohex(i, 2)\upper!

--     return encodeSet

-- percentEncode = (s, encodeSet, spaceAsPlus) ->
--     old = nil
--     if spaceAsPlus == true
--         old = encodeSet[" "]
--         encodeSet[" "] = "+"
--     s = gsub(s, "%W", encodeSet)
--     if old
--         encodeSet[" "] = old
--     return s

-- C0_ENCODE_SET = compilePercentEncodeSet({}, [0x00, 0x1F], [0x7F, 0xFF])
-- FRAGMENT_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, " ", "\"", "<", ">", "`")
-- QUERY_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, " ", "\"", "#", "<", ">")
-- SPECIAL_QUERY_ENCODE_SET = compilePercentEncodeSet(QUERY_ENCODE_SET, "'")
-- PATH_ENCODE_SET = compilePercentEncodeSet(QUERY_ENCODE_SET, "?", "`", "{", "}")
-- USERINFO_ENCODE_SET = compilePercentEncodeSet(PATH_ENCODE_SET, "/", ":", ";", "=", "@", [0x5B, 0x5E], "|")
-- COMPONENT_ENCODE_SET = compilePercentEncodeSet(USERINFO_ENCODE_SET, [0x24, 0x26], "+", ",")
-- URLENCODED_ENCODE_SET = compilePercentEncodeSet(COMPONENT_ENCODE_SET, "!", [0x27, 0x29], "~")
-- URI_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, 0x20, 0x22, 0x25, 0x3C, 0x3E, [0x42, 0x59], [0x5B, 0x5E], 0x60, [0x62, 0x79], [0x7B, 0x7D])

-- export encodeURI = (s) -> percentEncode(s, URI_ENCODE_SET)
-- export encodeURIComponent = (s) -> percentEncode(s, COMPONENT_ENCODE_SET, true)
-- export decodeURIComponent = (s) -> percentDecode(s, DECODE_LOOKUP_TABLE)
-- export decodeURI = (s) -> percentDecode(s, URI_DECODE_SET)

-- isLower = (ch) -> ch >= 0x61 --[['a']] and ch <= 0x7A --[['z']]
-- isUpper = (ch) -> ch >= 0x41 --[['A']] and ch <= 0x5A --[['Z']]
-- isAlpha = (ch) -> isLower(ch) or isUpper(ch)
-- isDigit = (ch) -> ch >= 0x30 --[['0']] and ch <= 0x39 --[['9']]
-- isHexDigit = (ch) -> isDigit(ch) or ch >= 0x41 --[['A']] and ch <= 0x46 --[['F']] or ch >= 0x61 --[['a']] and ch <= 0x66 --[['f']]
-- isSingleDot = (str) ->
--     return switch #str
--         when 1 then str == "."
--         when 3 then lower(str) == "%2e"
--         else false
-- isDoubleDot = (str) ->
--     return switch #str
--         when 2 then str == ".."
--         when 4
--             str = lower(str)
--             str == "%2e." or str == ".%2e"
--         when 6 then lower(str) == "%2e%2e"
--         else false
-- isWindowsDriveLetterCodePoints = (ch1, ch2, normalized) -> isAlpha(ch1) and (ch2 == 0x3A --[[':']] or (normalized == false and ch2 == 0x7C --[['|']]))
-- isWindowsDriveLetter = (str, normalized) -> return #str == 2 and isWindowsDriveLetterCodePoints(byte(str, 1), byte(str, 2), normalized)
-- startsWithWindowsDriveLetter = (str, startPos, endPos) ->
--     len = endPos - startPos + 1
--     return len >= 2 and
--         isWindowsDriveLetterCodePoints(byte(str, startPos), byte(str, startPos + 1), false) and
--         (len == 2 or FILE_OTHERWISE_CODE_POINTS[byte(str, startPos + 2)])

-- -- Converts character to digit,
-- -- if given non valid character it will return invalid number
-- charToDec = (ch) -> ch - 0x30
-- hexToDec = (ch) ->
--     if ch >= 0x61 --[['a']] then return ch - 0x61 + 10
--     elseif ch >= 0x41 --[['A']] then return ch - 0x41 + 10
--     else return charToDec(ch)

-- -- Finds nearest non whitespace character from startPos to endPos
-- -- And returns the position of that character
-- trimInput = (str, startPos, endPos) ->
--     for i = startPos, endPos, (startPos < endPos and 1 or -1)
--         ch = byte(str, i)
--         if not ch --[[ EOF ]] or ch > 0x20 --[[ C0 control or space ]]
--             return i
--     return endPos - 1

-- -- UTF-8 decoder from https://bjoern.hoehrmann.de/utf-8/decoder/dfa/
-- UTF8_DECODE_LOOKUP = []
-- do
--     UTF8_DECODE_LOOKUP_RULES = [
--         {0, 0x00, 0x7f}, {1, 0x80, 0x8f}, {9, 0x90, 0x9f}, {7, 0xa0, 0xbf},             -- 0x00 - 0xbf
--         {8, 0xc0, 0xc1}, {2, 0xc2, 0xdf}, {0xa, 0xe0}, {0x3, 0xe1, 0xef},               -- 0xc0 - 0xef
--         {0xb, 0xf0}, {0x6, 0xf1, 0xf3}, {0x5, 0xf4}, {0x8, 0xf5, 0xff},                 -- 0xf0 - 0xff
--         {0x0, 0x100}, {0x1, 0x101}, {0x2, 0x102}, {0x3, 0x103}, {0x5, 0x104}            -- 0x100 - 0x104
--         {0x8, 0x105}, {0x7, 0x106}, {0x1, 0x107, 0x10f}, {0x4, 0x10a}, {0x6, 0x10b},    -- 0x105 - 0x10f
--         {1, 0x110, 0x12f}, {0, 0x121}, {0, 0x127}, {0, 0x129},                          -- 0x110 - 0x12f
--         {1, 0x130, 0x14f}, {2, 0x131}, {2, 0x137}, {2, 0x139}, {2, 0x147},              -- 0x130 - 0x14f
--         {1, 0x150, 0x16f}, {2, 0x151}, {2, 0x159}, {3, 0x167}, {3, 0x169},              -- 0x150 - 0x16f
--         {1, 0x170, 0x18f}, {3, 0x171}, {3, 0x177}, {3, 0x179}, {3, 0x181}               -- 0x170 - 0x181
--     ] -- {val, start, end} / {val, pos}
--     for rule in *UTF8_DECODE_LOOKUP_RULES do
--         if rule[3]
--             for i = rule[2], rule[3] do UTF8_DECODE_LOOKUP[i] = rule[1]
--         else UTF8_DECODE_LOOKUP[rule[2]] = rule[1]

-- utf8Decode = (str, startPos, endPos) ->
--     -- TODO add support for fullwidth utf8/utf16
--     output = []
--     count = state = codep = 0
--     for i = startPos, endPos
--         b = byte(str, i)
--         t = UTF8_DECODE_LOOKUP[b]
--         codep = (state != 0) and
--             bor( band(b, 0x3f), lshift(codep, 6) ) or
--             band( rshift(0xff, t), b )
--         state = UTF8_DECODE_LOOKUP[256 + state * 16 + t]
--         if state == 0
--             count += 1
--             output[count] = codep
--     if state != 0
--         error "Invalid URL: UTF-8 decoding error"
--     return output

-- -- RFC 3492 Punycode encode
-- punycodeEncode = (str, startPos, endPos) ->
--     const base = 36
--     const tMin = 1
--     const tMax = 26
--     const skew = 38
--     const damp = 700
--     const initialBias = 72
--     const initialN = 0x80
--     const delimiter = 0x2D --[['-']]

--     -- Initialize the state
--     n = initialN
--     input = utf8Decode(str, startPos, endPos)
--     inputLen = #input
--     output = []
--     delta = out = 0
--     bias = initialBias

--     -- Handle the basic code points
--     for ch in *input
--         if ch < 0x80
--             out += 1
--             output[out] = char(ch)

--     -- h is the number of code points that have been handled, b is the number of basic code points
--     -- that have been handled, and out is the number of characters that have been output.
--     h = b = out

--     if b > 0
--         out += 1
--         output[out] = char(delimiter)

--     -- Main encoding loop
--     while h < inputLen
--         -- All non-basic code points < n have been handled already. Find the next larger one
--         m = 0x7FFFFFFF
--         for ch in *input
--             if ch >= n and ch < m then m = ch

--         -- Increase delta enough to advance the decoder's <n,i> state to <m,0>, but guard against overflow
--         if m - n > (0x7FFFFFFF - delta) / (h + 1)
--             error "Invalid URL: Punycode overflow"

--         delta += (m - n) * (h + 1)
--         n = m

--         for ch in *input
--             -- Punycode does not need to check whether input[j] is basic:
--             if ch < n
--                 delta += 1 -- Move this down incase of wrong answer
--                 if delta + 1 > 0x7FFFFFFF
--                     error "Invalid URL: Punycode overflow"
--             if ch == n
--                 -- Represent delta as a generalized variable-length integer
--                 q = delta
--                 k = base
--                 while true
--                     t = k <= bias and tMin or
--                         k >= bias + tMax and tMax or k - bias
--                     if q < t then break
--                     d = t + (q - t) % (base - t)
--                     out += 1
--                     output[out] = char(d + 22 + (d < 26 and 75 or 0))
--                     q = floor((q - t) / (base - t))
--                     k += base

--                 out += 1
--                 output[out] = char(q + 22 + (q < 26 and 75 or 0))

--                 k = 0
--                 delta = h == b and floor(delta / damp) or rshift(delta, 1)

--                 delta += floor(delta / (h + 1))
--                 while delta > ((base - tMin) * tMax) / 2
--                     delta = floor(delta / (base - tMin))
--                     k += base
--                 bias = floor(k + (base - tMin + 1) * delta / (delta + skew))
--                 delta = 0
--                 h += 1

--         delta += 1
--         n += 1

--     return concat(output, "", 1, out)

-- parseIPv4InIPv6 = (str, pointer, endPos, address, pieceIndex) ->
--     numbersSeen = 0
--     while pointer <= endPos
--         ipv4Piece = nil
--         ch = byte(str, pointer)
--         if numbersSeen > 0
--             unless ch == 0x2E --[['.']] and numbersSeen < 4
--                 error "Invalid URL: IPv4 in IPv6 invalid code point"
--             pointer += 1
--             ch = pointer <= endPos and byte(str, pointer)

--         while ch and isDigit(ch)
--             num = charToDec(ch)
--             unless ipv4Piece
--                 ipv4Piece = num
--             elseif ipv4Piece == 0
--                 error "Invalid URL: IPv4 in IPv6 invalid code point"
--             else
--                 ipv4Piece = ipv4Piece * 10 + num

--             if ipv4Piece > 255
--                 error "Invalid URL: IPv4 in IPv6 out of range part"

--             pointer += 1
--             ch = pointer <= endPos and byte(str, pointer)

--         unless ipv4Piece
--             error "Invalid URL: IPv4 in IPv6 invalid code point"

--         address[pieceIndex] = address[pieceIndex] * 0x100 + ipv4Piece
--         numbersSeen += 1
--         if numbersSeen == 2 or numbersSeen == 4
--             pieceIndex += 1

--     if numbersSeen != 4
--         error "Invalid URL: IPv4 in IPv6 too few parts"

--     return pieceIndex

-- parseIPv6 = (str, startPos, endPos) ->
--     address = [0, 0, 0, 0, 0, 0, 0, 0] -- ipv6 address
--     pointer = startPos
--     pieceIndex = 1
--     compress = nil

--     if byte(str, startPos) == 0x3A -- ':'
--         if startPos == endPos --[[ EOF ]] or byte(str, startPos + 1) != 0x3A -- ':'
--             error "Invalid URL: IPv6 invalid compression"
--         pointer += 2
--         pieceIndex = compress = 2

--     while pointer <= endPos
--         if pieceIndex == 9
--             error "Invalid URL: IPv6 too many pieces"

--         ch = byte(str, pointer)
--         if ch == 0x3A -- ':'
--             if compress
--                 error "Invalid URL: IPv6 multiple compression"
--             pointer += 1
--             pieceIndex = compress = pieceIndex + 1
--             continue

--         value = length = 0
--         while length < 4 and ch and isHexDigit(ch)
--             value = value * 0x10 + hexToDec(ch)
--             pointer += 1
--             length += 1
--             ch = pointer <= endPos and byte(str, pointer)

--         if ch == 0x2E -- '.'
--             if length == 0
--                 error "Invalud URL: IPv4 in IPv6 invalid code point"

--             pointer -= length
--             if pieceIndex > 7
--                 error "Invalid URL: IPv4 in IPv6 too many pieces"

--             pieceIndex = parseIPv4InIPv6(str, pointer, endPos, address, pieceIndex)
--             break
--         elseif ch == 0x3A -- ':'
--             pointer += 1
--             if pointer > endPos -- EOF
--                 error "Invalid URL: IPv6 invalid code point"
--         elseif pointer <= endPos
--             error "Invalid URL: IPv6 invalid code point"

--         address[pieceIndex] = value
--         pieceIndex += 1

--     if compress
--         swaps = pieceIndex - compress
--         pieceIndex = 8
--         while pieceIndex != 1 and swaps > 0
--             value = address[pieceIndex]
--             address[pieceIndex] = address[compress + swaps - 1]
--             address[compress + swaps - 1] = value
--             swaps -= 1
--             pieceIndex -= 1
--     elseif pieceIndex != 9
--         error "Invalid URL: IPv6 too few pieces"

--     return address

-- parseIPv4Number = (str) ->
--     if str == ""
--         return
--     radix = 10
--     ch1 = byte(str, 1)
--     ch2 = byte(str, 2)
--     if ch1 == 0x30 --[['0']] and (ch2 == 0x78 --[['x']] or ch2 == 0x58 --[['X']])
--         radix = 16
--         if #str == 2 then str = "0"
--     elseif ch1 == 0x30 --[['0']] and ch2
--         radix = 8
--     return tonumber(str, radix)

-- endsInANumberChecker = (str, startPos, endPos) ->
--     -- find a starting point for number
--     numStart = startPos
--     numEnd = endPos
--     for i = numEnd, numStart, -1
--         if byte(str, i) == 0x2E --[['.']]
--             if i == endPos -- if dot is at the end, then skip it
--                 numEnd = i - 1
--             else -- dot was found, so after it must be a number
--                 numStart = i + 1
--                 break

--     -- sanity check, do not invoke parser if we have ONLY digits
--     for i = numStart, numEnd
--         if not isDigit byte(str, i)
--             -- welp, let us try at least parse it, what if it is a hex number
--             return parseIPv4Number sub(str, numStart, numEnd)

--     return numStart <= numEnd -- every charactar was a digit, yay!

-- parseIPv4 = (str, startPos, endPos) ->
--     numbers = []
--     pointer = startPos
--     while true
--         ch = pointer <= endPos and byte(str, pointer)
--         if not ch or ch == 0x2E -- '.'
--             num = parseIPv4Number sub(str, startPos, pointer - 1)
--             if not num
--                 if pointer > endPos and #numbers > 0
--                     break
--                 error "Invalid URL: IPv4 non numeric part"

--             startPos = pointer + 1
--             numbers[] = num
--             if not ch
--                 break

--         pointer += 1

--     if #numbers > 4
--         error "Invalid URL: IPv4 too many parts"

--     for i = 1, #numbers - 1
--         if numbers[i] > 255
--             error "Invalid URL: IPv4 out of range part"

--     if numbers[#numbers] >= 256 ^ (5 - #numbers)
--         error "Invalid URL: IPv4 out of range part"

--     ipv4 = numbers[#numbers]
--     counter = 0
--     for i = 1, #numbers - 1
--         ipv4 += numbers[i] * 256 ^ (3 - counter)
--         counter += 1
--     return ipv4

-- domainToASCII = (domain) ->
--     for i = 1, #domain
--         if byte(domain, i) > 0x7F
--             -- We are dealing with some complicated unicode domain name
--             -- Since I am lazy newbie who does not want to implement proper unicode
--             -- handling into lua, I'll just cover edge cases for tests
--             -- You can open issue on Github if it REALLY BOTHERS YOU
--             -- But if it REALLY BOTHERS YOU then feel free to make proper unicode support
--             -- yourself :)

--             -- Remove special symbols that are ignored
--             -- I probably really should implement some proper punycode
--             domain = gsub(domain, "\xC2\xAD", "") -- remove soft hyphen
--             domain = gsub(domain, "\xE3\x80\x82", ".") -- Ideographic full stop
--             -- remove space characters
--             domain = gsub(domain, "\xE2\x80\x8B", "")
--             domain = gsub(domain, "\xE2\x81\xA0", "")
--             domain = gsub(domain, "\xEF\xBB\xBF", "")

--             break

--     containsNonASCII = doLowerCase = false
--     punycodePrefix = 0
--     partStart = pointer = 1
--     parts = []
--     while true
--         ch = byte(domain, pointer)
--         if not ch or ch == 0x2E -- '.'
--             -- decode an find errors
--             if punycodePrefix == 4 and containsNonASCII
--                 error "Invalid URL: Domain invalid code point"

--             domainPart = containsNonASCII and "xn--" .. punycodeEncode(domain, partStart, pointer - 1) or sub(domain, partStart, pointer - 1)
--             -- btw, punycode decode lowercases the domain, so we need to lowercase it
--             -- in ideal sutiation I should have written punycodeDecode, but I am not in the mood to write it
--             if doLowerCase
--                 domainPart = lower(domainPart)

--             parts[] = domainPart
--             partStart = pointer + 1
--             containsNonASCII = doLowerCase = false
--             punycodePrefix = 0
--             if not ch
--                 break
--         elseif ch > 0x7F
--             containsNonASCII = true
--         elseif PUNYCODE_PREFIX[pointer - partStart + 1] == ch
--             punycodePrefix += 1
--         elseif isUpper(ch)
--             doLowerCase = true

--         pointer += 1

--     return concat(parts, ".")

-- parseHostString = (str, startPos, endPos, isSpecial) ->
--     if byte(str, startPos) == 0x5B -- '['
--         if byte(str, endPos) != 0x5D -- ']'
--             error "Invalid URL: IPv6 unclosed"

--         return parseIPv6(str, startPos + 1, endPos - 1)
--     elseif not isSpecial
--         -- opaque host parsing
--         if containsCharacter(str, FORBIDDEN_HOST_CODE_POINTS, startPos, endPos)
--             error "Invalid URL: Host invalid code point"

--         return percentEncode(sub(str, startPos, endPos), C0_ENCODE_SET)
--     else
--         domain = percentDecode(sub(str, startPos, endPos), DECODE_LOOKUP_TABLE)
--         asciiDomain = domainToASCII(domain)

--         if containsCharacter(asciiDomain, FORBIDDEN_DOMAIN_CODE_POINTS)
--             error "Invalid URL: Domain invalid code point"

--         if endsInANumberChecker(asciiDomain, 1, #asciiDomain)
--             return parseIPv4(asciiDomain, 1, #asciiDomain)

--         return asciiDomain

-- -- Predefine locals so we can make functions in the order I want (as if you were reading specs)
-- local parseScheme, parseNoScheme, parseSpecialRelativeOrAuthority, parsePathOrAuthority
-- local parseRelative, parseRelativeSlash, parseSpecialAuthorityIgnoreSlashes, parseAuthority
-- local parseHost, parsePort, parseFile, parseFileSlash, parseFileHost, parsePathStart, parsePath, parseOpaquePath
-- local parseQuery, parseFragment

-- parseScheme = (str, startPos, endPos, base, stateOverride) =>
--     -- scheme start state
--     if startPos <= endPos and isAlpha byte(str, startPos)
--         -- scheme state
--         doLowerCase = false
--         scheme = nil
--         for i = startPos, endPos
--             ch = byte(str, i)
--             if ch == 0x3A -- ':'
--                 scheme = sub(str, startPos, i - 1)
--                 if doLowerCase
--                     scheme = lower(scheme)

--                 isSpecial = SPECIAL_SCHEMAS[scheme]
--                 if stateOverride
--                     isUrlSpecial = @scheme and SPECIAL_SCHEMAS[@scheme]
--                     if isUrlSpecial and not isSpecial then return
--                     if not isUrlSpecial and isSpecial then return
--                     if @username or @password or @port and isSpecial == true then return
--                     if isUrlSpecial == true and @hostname != "" then return

--                 @scheme = scheme

--                 if stateOverride
--                     if @port == isSpecial
--                         @port = nil
--                 elseif isSpecial == true -- scheme is file:
--                     -- file state
--                     parseFile(@, str, i + 1, endPos, base)
--                 elseif isSpecial and base and base.scheme == scheme
--                     -- special relative or authority state
--                     parseSpecialRelativeOrAuthority(@, str, i + 1, endPos, base, isSpecial)
--                 elseif isSpecial
--                     -- special authority slashes state
--                     parseSpecialAuthorityIgnoreSlashes(@, str, i + 1, endPos, base, isSpecial) -- anyway state will ignore slashes
--                 elseif byte(str, i + 1) == 0x2F --[['/']]
--                     -- path or authority state
--                     parsePathOrAuthority(@, str, i + 2, endPos, base)
--                 else
--                     -- opaque path state
--                     parseOpaquePath(@, str, i + 1, endPos)
--                 return
--             elseif isUpper(ch)
--                 doLowerCase = true
--             elseif not isLower(ch) and not isDigit(ch) and ch != 0x2B --[['+']] and ch != 0x2D --[['-']] and ch != 0x2E --[['.']]
--                 -- scheme have an invalid character, so it's not a scheme
--                 break

--     if not stateOverride
--         -- no scheme state
--         parseNoScheme(@, str, startPos, endPos, base)

-- parseNoScheme = (str, startPos, endPos, base) =>
--     startsWithFragment = byte(str, startPos) == 0x23 --[['#']]
--     baseHasOpaquePath = base and isstring(base.path)
--     if not base or (baseHasOpaquePath and not startsWithFragment)
--         error "Invalid URL: Missing scheme"

--     if baseHasOpaquePath and startsWithFragment
--         @scheme = base.scheme
--         @path = base.path
--         @query = base.query
--         parseFragment(@, str, startPos + 1, endPos)
--     elseif base.scheme != "file"
--         parseRelative(@, str, startPos, endPos, base, SPECIAL_SCHEMAS[base.scheme])
--     else
--         @scheme = "file"
--         parseFile(@, str, startPos, endPos, base)

-- parseSpecialRelativeOrAuthority = (str, startPos, endPos, base, isSpecial) =>
--     if byte(str, startPos) == 0x2F --[['/']] and byte(str, startPos + 1) == 0x2F --[['/']]
--         -- special authority slashes state
--         parseSpecialAuthorityIgnoreSlashes(@, str, startPos + 2, endPos, base, isSpecial)
--     else
--         -- relative state
--         @scheme = base.scheme
--         parseRelative(@, str, startPos, endPos, base, isSpecial)

-- parsePathOrAuthority = (str, startPos, endPos, base) =>
--     if byte(str, startPos) == 0x2F --[['/']]
--         parseAuthority(@, str, startPos + 1, endPos)
--     else
--         parsePath(@, str, startPos, endPos)

-- parseRelative = (str, startPos, endPos, base, isSpecial) =>
--     @scheme = base.scheme
--     ch = startPos <= endPos and byte(str, startPos)
--     if ch == 0x2F --[['/']] or (isSpecial and ch == 0x5C --[['\']])
--         -- relative slash state
--         parseRelativeSlash(@, str, startPos + 1, endPos, base, isSpecial)
--     else
--         @username = base.username
--         @password = base.password
--         @hostname = base.hostname
--         @port = base.port
--         path = @path = {...(base.path or {})} -- clone path
--         if ch == 0x3F --[['?']]
--             parseQuery(@, str, startPos + 1, endPos)
--         elseif ch == 0x23 --[['#']]
--             @query = base.query
--             parseFragment(@, str, startPos + 1, endPos)
--         elseif ch -- not EOF
--             pathLen = #path
--             if pathLen != 1 or not isWindowsDriveLetter(path[1])
--                 path[pathLen] = nil -- removing last path segment
--             parsePath(@, str, startPos, endPos, isSpecial, path)


-- parseRelativeSlash = (str, startPos, endPos, base, isSpecial) =>
--     ch = byte(str, startPos)
--     if isSpecial and (ch == 0x2F --[['/']] or ch == 0x5C --[['\']])
--         -- special authority ignore slashes state
--         parseSpecialAuthorityIgnoreSlashes(@, str, startPos + 1, endPos, base, isSpecial)
--     elseif ch == 0x2F --[['/']]
--         -- authority state
--         parseAuthority(@, str, startPos + 1, endPos, isSpecial)
--     else
--         @username = base.username
--         @password = base.password
--         @hostname = base.hostname
--         @port = base.port
--         parsePath(@, str, startPos, endPos, isSpecial)

-- parseSpecialAuthorityIgnoreSlashes = (str, startPos, endPos, base, isSpecial) =>
--     for i = startPos, endPos
--         ch = byte(str, i)
--         if ch != 0x2F --[['/']] and ch != 0x5C --[['\']]
--             parseAuthority(@, str, i, endPos, isSpecial)
--             break

-- parseAuthority = (str, startPos, endPos, isSpecial) =>
--     -- authority state
--     atSignSeen = false
--     passwordTokenSeen = false
--     pathEndPos = endPos
--     for i = startPos, endPos
--         ch = byte(str, i)
--         if ch == 0x2F --[['/']] or ch == 0x3F --[['?']] or ch == 0x23 --[['#']] or (isSpecial and ch == 0x5C --[['\']])
--             endPos = i - 1
--             break
--         elseif ch == 0x40 -- '@'
--             atSignSeen = i
--         elseif ch == 0x3A --[[':']] and not passwordTokenSeen and not atSignSeen
--             passwordTokenSeen = i

--     -- After @ there is no hostname
--     if atSignSeen == endPos
--         error "Invalid URL: Missing host"

--     if atSignSeen
--         if passwordTokenSeen
--             @username = percentEncode(sub(str, startPos, passwordTokenSeen - 1), USERINFO_ENCODE_SET)
--             @password = percentEncode(sub(str, passwordTokenSeen + 1, atSignSeen - 1), USERINFO_ENCODE_SET)
--         else
--             @username = percentEncode(sub(str, startPos, atSignSeen - 1), USERINFO_ENCODE_SET)

--     parseHost(@, str, atSignSeen and atSignSeen + 1 or startPos, endPos, isSpecial)
--     parsePathStart(@, str, endPos + 1, pathEndPos, isSpecial)

-- parseHost = (str, startPos, endPos, isSpecial, stateOverride) =>
--     if stateOverride and isSpecial == true
--         return parseFileHost(@, str, startPos, endPos, stateOverride)

--     insideBrackets = false
--     for i = startPos, endPos
--         ch = byte(str, i)
--         if ch == 0x3A --[[':']] and not insideBrackets
--             if i == startPos
--                 error "Invalid URL: Missing host"
--             if stateOverride == "hostname"
--                 return

--             parsePort(@, str, i + 1, endPos, isSpecial, stateOverride)

--             endPos = i - 1
--             break
--         elseif ch == 0x5B -- '['
--             insideBrackets = true
--         elseif ch == 0x5D -- ']'
--             insideBrackets = false

--     if isSpecial and startPos > endPos
--         error "Invalid URL: Missing host"
--     elseif stateOverride and startPos == endPos and (@username or @password or @port)
--         return

--     @hostname = parseHostString(str, startPos, endPos, isSpecial)

-- parsePort = (str, startPos, endPos, defaultPort, stateOverride) =>
--     if startPos > endPos
--         return

--     port = tonumber sub(str, startPos, endPos)
--     if not port or (port > 2 ^ 16 - 1) or port < 0
--         if stateOverride then
--             return
--         error "Invalid URL: Invalid port"

--     if port != defaultPort
--         @port = port

-- parseFile = (str, startPos, endPos, base) =>
--     @scheme = "file"
--     @hostname = ""
--     ch = startPos <= endPos and byte(str, startPos)
--     if ch == 0x2F --[['/']] or ch == 0x5C --[['\']]
--         parseFileSlash(@, str, startPos + 1, endPos, base)
--     elseif base and base.scheme == "file"
--         @hostname = base.hostname
--         path = @path = {...(base.path or {})}
--         if ch == 0x3F --[['?']]
--             parseQuery(@, str, startPos + 1, endPos)
--         elseif ch == 0x23 --[['#']]
--             @query = base.query
--             parseFragment(@, str, startPos + 1, endPos)
--         elseif ch -- not EOF
--             pathLen = #path
--             if not startsWithWindowsDriveLetter(str, startPos, endPos)
--                 if pathLen != 1 or not isWindowsDriveLetter(path[1])
--                     path[pathLen] = nil -- removing last path segment
--             else
--                 path = nil
--             parsePath(@, str, startPos, endPos, true, path)
--     else
--         parsePath(@, str, startPos, endPos, true)

-- parseFileSlash = (str, startPos, endPos, base) =>
--     ch = byte(str, startPos)
--     if ch == 0x2F --[['/']] or ch == 0x5C --[['\']]
--         parseFileHost(@, str, startPos + 1, endPos)
--     else
--         path = {}
--         if base and base.scheme == "file"
--             @hostname = base.hostname
--             if not startsWithWindowsDriveLetter(str, startPos, endPos) and isWindowsDriveLetter(base.path[1], false)
--                 path[1] = base.path[1]
--         parsePath(@, str, startPos, endPos, true, path)

-- parseFileHost = (str, startPos, endPos, stateOverride) =>
--     i = startPos
--     while true
--         ch = i <= endPos and byte(str, i)
--         if ch == 0x2F --[['/']] or ch == 0x5C --[['\']] or ch == 0x3F --[['?']] or ch == 0x23 --[['#']] or not ch -- EOF
--             hostLen = i - startPos
--             if not stateOverride and hostLen == 2 and isWindowsDriveLetterCodePoints(byte(str, startPos), byte(str, startPos + 1), false)
--                 parsePath(@, str, startPos, endPos, true)
--             elseif hostLen == 0
--                 @hostname = ""
--                 if stateOverride
--                     return

--                 parsePathStart(@, str, i, endPos, true)
--             else
--                 hostname = parseHostString(str, startPos, i - 1, true)
--                 if hostname == "localhost"
--                     hostname = ""

--                 @hostname = hostname
--                 if stateOverride
--                     return

--                 parsePathStart(@, str, i, endPos, true)
--             break
--         i += 1

-- parsePathStart = (str, startPos, endPos, isSpecial, stateOverride) =>
--     ch = startPos <= endPos and byte(str, startPos)
--     if isSpecial
--         if ch == 0x2F --[['/']] or ch == 0x5C --[['\']]
--             startPos += 1
--         parsePath(@, str, startPos, endPos, isSpecial, nil, stateOverride)
--     elseif not stateOverride and ch == 0x3F --[['?']]
--         parseQuery(@, str, startPos + 1, endPos)
--     elseif not stateOverride and ch == 0x23 --[['#']]
--         parseFragment(@, str, startPos + 1, endPos)
--     elseif ch -- not EOF
--         if ch == 0x2F --[['/']]
--             startPos += 1
--         parsePath(@, str, startPos, endPos, isSpecial, nil, stateOverride)
--     elseif stateOverride and not @hostname
--         @path[] = "" -- append empty string to path

-- parsePath = (str, startPos, endPos, isSpecial, segments={}, stateOverride) =>
--     segmentsCount = #segments
--     hasWindowsLetter = segmentsCount != 0 and isWindowsDriveLetter(segments[1], false)
--     segmentStart = startPos

--     i = startPos
--     while true
--         ch = i <= endPos and byte(str, i)
--         if ch == 0x2F --[['/']] or (isSpecial and ch == 0x5C --[['\']]) or (not stateOverride and (ch == 0x3F --[['?']] or ch == 0x23 --[['#']])) or not ch -- EOF
--             segment = percentEncode(sub(str, segmentStart, i - 1), PATH_ENCODE_SET)
--             segmentStart = i + 1
--             if isDoubleDot(segment)
--                 if segmentsCount != 1 or not hasWindowsLetter
--                     segments[segmentsCount] = nil
--                     segmentsCount -= 1
--                     if segmentsCount == -1 then segmentsCount = 0 -- do not allow underflow
--                 if ch != 0x2F --[['/']] and (isSpecial and ch != 0x5C --[['\']])
--                     segmentsCount += 1
--                     segments[segmentsCount] = ""
--             elseif not isSingleDot(segment)
--                 if isSpecial == true --[[is file scheme]] and segmentsCount == 0 and isWindowsDriveLetter(segment, false)
--                     segment = gsub(segment, "|", ":")
--                     hasWindowsLetter = true
--                 segmentsCount += 1
--                 segments[segmentsCount] = segment
--             elseif ch != 0x2F --[['/']] and (isSpecial and ch != 0x5C --[['\']])
--                 segmentsCount += 1
--                 segments[segmentsCount] = ""

--             if ch == 0x3F --[['?']]
--                 parseQuery(@, str, i + 1, endPos)
--                 break
--             elseif ch == 0x23 --[['#']]
--                 parseFragment(@, str, i + 1, endPos)
--                 break
--             elseif not ch
--                 break

--         i += 1

--     @path = segments

-- parseOpaquePath = (str, startPos, endPos) =>
--     for i = startPos, endPos
--         ch = byte(str, i)
--         if ch == 0x3F --[['?']]
--             parseQuery(@, str, i + 1, endPos)
--             endPos = i - 1
--             break
--         elseif ch == 0x23 --[['#']]
--             parseFragment(@, str, i + 1, endPos)
--             endPos = i - 1
--             break

--     @path = percentEncode(sub(str, startPos, endPos), C0_ENCODE_SET)

-- parseQuery = (str, startPos, endPos, isSpecial, stateOverride) =>
--     for i = startPos, endPos
--         if not stateOverride and byte(str, i) == 0x23 --[['#']]
--             parseFragment(@, str, i + 1, endPos)
--             endPos = i - 1
--             break

--     encodeSet = isSpecial and SPECIAL_QUERY_ENCODE_SET or QUERY_ENCODE_SET
--     @query = percentEncode(sub(str, startPos, endPos), encodeSet)

-- -- This methods parses given query string to a list of name-value tuple
-- parseQueryString = (str, output=[]) ->
--     pointer = startPos = 1
--     name = value = nil
--     containsPlus = false
--     count = 0
--     while true
--         ch = byte(str, pointer)
--         if ch == 0x26 --[['&']] or not ch -- EOF
--             value = sub(str, startPos, pointer - 1)
--             if containsPlus
--                 value = gsub(name, "%+", " ")
--                 containsPlus = false

--             unless name
--                 name = value
--                 value = nil

--             if name != "" or value
--                 name = percentDecode(name, DECODE_LOOKUP_TABLE)
--                 value = value and percentDecode(value, DECODE_LOOKUP_TABLE) or nil
--                 count += 1
--                 output[count] = [name, value]

--             name = value = nil
--             startPos = pointer + 1
--             if not ch -- EOF
--                 break
--         elseif ch == 0x3D -- '='
--             name = sub(str, startPos, pointer - 1)
--             startPos = pointer + 1
--             if containsPlus
--                 name = gsub(name, "%+", " ")
--                 containsPlus = false
--         elseif ch == 0x2B --[['+']]
--             containsPlus = true

--         pointer += 1
--     return output

-- parseFragment = (str, startPos, endPos) =>
--     @fragment = percentEncode(sub(str, startPos, endPos), FRAGMENT_ENCODE_SET)

-- export parse = (str, base) =>
--     unless isstring str
--         error "Invalid URL: URL must be a string"

--     if isstring base
--         -- yeah, we dont even need to full URL object for this
--         url = {}
--         parse(url, base)
--         base = url

--     str = gsub(str, "[\t\n\r]", "") -- remove all tab and newline characters
--     startPos = 1
--     endPos = #str

--     -- Trim leading and trailing whitespaces
--     startPos = trimInput(str, startPos, endPos)
--     endPos = trimInput(str, endPos, startPos)

--     parseScheme(@, str, startPos, endPos, base)
--     return @

-- serializeIPv6 = (address) ->
--     output = []
--     len = compress = compressLen = zeroStart = 0
--     -- Find first longest sequence of zeros
--     for i = 1, 8
--         if address[i] == 0
--             if zeroStart == 0
--                 zeroStart = i
--             elseif i - zeroStart > compressLen
--                 compress = zeroStart
--                 compressLen = i - zeroStart
--         else
--             zeroStart = 0

--     ignore0 = false
--     for i = 1, 8
--         if ignore0
--             if address[i] == 0
--                 continue
--             ignore0 = false
--         if compress == i
--             len += 1
--             output[len] = i == 1 and "::" or ":"
--             ignore0 = true
--             continue
--         len += 1
--         output[len] = format("%x", address[i]) -- 🤔 I believe it is fastest way to represent a number as hex in lua
--         -- why format? because it returns hex without zeros (aka smallest hex value)
--         if i != 8
--             len += 1
--             output[len] = ":"

--     return concat(output, "", 1, len)

-- serializeHost = (host) ->
--     if istable host
--         return "[" .. serializeIPv6(host) .. "]"
--     elseif isnumber host
--         address = []
--         for i = 1, 4
--             address[5 - i] = format("%u", host % 256)
--             host = floor(host / 256)
--         return concat(address, ".")
--     return host

-- serializeQuery = (query) ->
--     unless istable(query)
--         return query

--     output, length = {}, 0

--     for t in *query
--         if length > 0
--             length += 1
--             output[length] = "&"

--         length += 1
--         output[length] = t[1] and percentEncode(t[1], URLENCODED_ENCODE_SET, true) or ""

--         value = t[2] and percentEncode(t[2], URLENCODED_ENCODE_SET, true) or ""
--         if value != ""
--             length += 1
--             output[length] = "="

--             length += 1
--             output[length] = value

--     if length != 0
--         return concat(output, "", 1, length)

-- export serialize = (excludeFragment) =>
--     scheme = @scheme
--     hostname = @hostname
--     path = @path
--     query = @query
--     fragment = @fragment
--     isOpaque = isstring(path)

--     output, length = [], 0

--     if scheme
--         length += 1
--         output[length] = scheme

--         length += 1
--         output[length] = ":"

--     if hostname
--         length += 1
--         output[length] = "//"

--         username = @username
--         password = @password

--         if username or password
--             length += 1
--             output[length] = username

--             if password and password != ""
--                 length += 1
--                 output[length] = ":"

--                 length += 1
--                 output[length] = password

--             length += 1
--             output[length] = "@"

--         length += 1
--         output[length] = serializeHost(hostname)

--         if port := @port
--             length += 1
--             output[length] = ":"

--             length += 1
--             output[length] = tostring(port)

--     elseif path and not isOpaque and #path > 1 and path[1] == ""
--         length += 1
--         output[length] = "./"

--     if path
--         length += 1
--         output[length] = isOpaque and path or "/" .. concat(path, "/")

--     if query and #query != 0
--         length += 1
--         output[length] = "?"

--         length += 1
--         output[length] = tostring(query) or ""

--     if fragment and excludeFragment != true
--         length += 1
--         output[length] = "#"

--         length += 1
--         output[length] = fragment

--     return concat(output, "", 1, length)

-- getOrigin = =>
--     switch @scheme
--         when "ftp", "http", "https", "ws", "wss"
--             return @scheme, @hostname, @port
--         when "blob"
--             pathURL = @path
--             if not isstring pathURL
--                 return
--             ok, url = pcall(parse, {}, pathURL)
--             if ok
--                 return getOrigin(url)
--         -- otherwise it is opaque

-- serializeOrigin = =>
--     scheme, hostname, port = getOrigin(@)
--     if scheme
--         output = scheme .. "://" .. serializeHost(hostname)
--         if port
--             output = output .. ":" .. port
--         return output

-- export class URLSearchParams
--     new: (query, @url) =>
--         if isstring query
--             if byte(query, 1) == 0x3F --[['?']]
--                 query = sub(query, 2)

--             parseQueryString(query, @) -- will parse query string into URLSearchParams itself
--         elseif istable query
--             for i = 1, #query do @[i] = query[i]

--         if @url
--             -- yeah, URLState.query may be a string or URLSearchParams
--             -- when we access URL.searchParams, it will look for URLState.query
--             @url.state.query = @

--     __tostring: => serializeQuery(@)

--     update = =>
--         if @url
--             @url.query = @ -- trigger cache reset with query setter

--     append: (list, name, value) ->
--         list[] = [name, value]
--         update(list)

--     delete: (list, name, value) ->
--         for i = #list, 1, -1
--             t = list[i]
--             if t[1] == name and (not value or t[2] == value)
--                 remove(list, i)
--         update(list)

--     get: (list, name) ->
--         for t in *list
--             if t[1] == name
--                 return t[2]

--     getAll: (list, name) ->
--         values = []
--         for t in *list
--             if t[1] == name
--                 values[] = t[2]
--         return values

--     has: (list, name, value) ->
--         for t in *list
--             if t[1] == name and (not value or t[2] == value)
--                 return true
--         return false

--     set: (list, name, value) ->
--         for i = 1, #list
--             t = list[i]
--             if t[1] == name
--                 -- replace first value
--                 t[2] = value
--                 -- remove all other values
--                 for j = #list, i + 1, -1
--                     if list[j][1] == name
--                         remove(list, j)
    
--                 update(list)
--                 return

--         -- if name is not found, append new value
--         list[] = [name, value]
--         update(list)

--     sort: (list) ->
--         for i = 1, #list - 1
--             jMin = i
--             for j = i + 1, #list
--                 if list[j][1] < list[jMin][1]
--                     jMin = j

--             if jMin != i
--                 old = list[i]
--                 list[i] = list[jMin]
--                 list[jMin] = old
--         update(list)

--     iterator: (list) ->
--         i = 0
--         return ->
--             i += 1
--             t = list[i]
--             if t then return t[1], t[2]

--     keys: (list) ->
--         i = 0
--         return ->
--             i += 1
--             t = list[i]
--             if t then return t[1]

--     values: (list) ->
--         i = 0
--         return ->
--             i += 1
--             t = list[i]
--             if t then return t[2]


-- export IsURLSearchParams = ( any ) ->
--     metatable = getmetatable( any )
--     return metatable and metatable.__class == URLSearchParams

-- export class URL
--     new: (str, base) =>
--         state = @state = {}
--         parse(state, str, base)

--     @parse: (str, base) -> URL(str, base)
--     @canParse: (str, base) -> pcall(parse, {}, str, base)

--     STATE_FIELDS = {"scheme": true, "username": true, "password": true, "hostname": true, "port": true, "path": true, "query": true, "fragment": true}

--     resetCache = =>
--         rawset(@, "_href", nil)
--         rawset(@, "_origin", nil)
--         rawset(@, "_host", nil)
--         rawset(@, "_hostname", nil)
--         rawset(@, "_pathname", nil)
--         rawset(@, "_query", nil)

--     cacheValue = (key, value) =>
--         rawset(@, key, value)
--         return value

--     __tostring: => @href

--     __index: (key) =>
--         state = rawget(@, "state")

--         -- State fields
--         if STATE_FIELDS[key]
--             switch key
--                 when "hostname" then return rawget(@, "_hostname") or cacheValue(@, "_hostname", serializeHost(state.hostname))
--                 when "query"
--                     return rawget(@, "_query") or cacheValue(@, "_query", IsURLSearchParams(state.query) and tostring(state.query) or state.query)
--                 else return state[key]

--         -- Special fields
--         return switch key
--             when "href" then return rawget(@, "_href") or cacheValue(@, "_href", serialize(state))
--             when "origin" then return rawget(@, "_origin") or cacheValue(@, "_origin", serializeOrigin(state))
--             when "protocol" then return state.scheme and state.scheme .. ":" or nil
--             when "host"
--                 if cached := rawget(@, "_host") then return cached
--                 if not state.hostname then return ""
--                 return cacheValue(@, "_host", state.port and @hostname .. ":" .. state.port or @hostname)
--             when "pathname"
--                 if cached := rawget(@, "_pathname") then return cached
--                 if not istable(state.path) then return state.path
--                 return cacheValue(@, "_pathname", "/" .. concat(state.path, "/"))
--             when "search"
--                 query = @query -- get cached query, or serialize it
--                 if not query or query == "" then return ""
--                 return "?" .. query
--             when "searchParams"
--                 if IsURLSearchParams(state.query) then return state.query
--                 return URLSearchParams(state.query, @)
--             when "hash"
--                 if not state.fragment or state.fragment == "" then return ""
--                 return "#" .. state.fragment

--     __newindex: (key, value) =>
--         state = rawget(@, "state")

--         -- State fields
--         if STATE_FIELDS[key]
--             resetCache(@)
--             switch key
--                 when "username"
--                     if not state.hostname or state.hostname == "" or state.scheme == "file"
--                         return
--                     state.username = value
--                 when "password"
--                     if not state.hostname or state.hostname == "" or state.scheme == "file"
--                         return
--                     state.password = value
--                 when "hostname"
--                     if isstring(state.path)
--                         return
--                     parseHost(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], "hostname")
--                 when "port"
--                     if not state.hostname or state.hostname == "" or state.scheme == "file"
--                         return

--                     if not value or value == ""
--                         state.port = nil
--                         return
--                     else
--                         value = tostring(value)
--                         parsePort(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
--                 else state[key] = value
--             return

--         -- Special fields
--         switch key
--             when "href"
--                 resetCache(@)
--                 state = {}
--                 parse(state, value)
--                 rawset(@, "state", state)
--             when "origin" then return -- readonly field
--             when "protocol"
--                 resetCache(@)
--                 parseScheme(state, value, 1, #value, nil, true)
--             when "host"
--                 if isstring(state.path)
--                     return
--                 resetCache(@)
--                 parseHost(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], "host")
--             when "pathname"
--                 if isstring(state.path)
--                     return -- cannot set pathname when path is opaque
--                 resetCache(@)
--                 state.path = {}
--                 parsePathStart(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
--             when "search"
--                 resetCache(@)
--                 leadingSymbol = byte(value, 1) == 0x3F --[['?']]
--                 parseQuery(state, value, leadingSymbol and 2 or 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
--             when "searchParams" then return -- readonly field
--             when "hash"
--                 if not value or value == ""
--                     state.fragment = nil
--                     return
--                 resetCache(@)
--                 leadingSymbol = byte(value, 1) == 0x23 --[['#']]
--                 parseFragment(state, value, leadingSymbol and 2 or 1, #value)
--             else rawset(@, key, value)

-- export IsURL = ( any ) ->
--     metatable = getmetatable( any )
--     return metatable and metatable.__class == URL

-- URL.lua

local std = gpm.std


---@alias URL gpm.std.URL
---@class gpm.std.URL : gpm.std.Object
---@field __class gpm.std.URLClass
local URL = std.class.base("URL")

---@class gpm.std.URLClass : gpm.std.URL
---@field __base URL
local URLClass = std.class.create(URL)

return URLClass
