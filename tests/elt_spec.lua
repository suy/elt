require '../tests/luassert-reversed-en'

local elt = require 'elt'

--------------------------------------------------------------------------------
describe('The elt module', function()
    it('has the basics in it', function()
        assert.is_string(elt._COPYRIGHT)
        assert.is_string(elt._DESCRIPTION)
        assert.is_string(elt._VERSION)

        assert.is_table(elt.Chunks)
        assert.is_table(elt.Generator)
        assert.is_table(elt.Parser)

        assert.is_function(elt.compile)
        assert.is_function(elt.render)
    end)

end)


--------------------------------------------------------------------------------
describe('Chunks helper', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Chunks)
        assert.is_function(elt.Chunks.new)
        assert.is_function(elt.Chunks.append)
    end)

    it('can create instances with `new`', function()
        local chunks = elt.Chunks:new()
        assert.is_table(chunks)
        assert.is_table(getmetatable(chunks))
        assert.is_same(getmetatable(chunks), elt.Chunks)
    end)

    it('has an append function with two overloads', function()
        local chunks = elt.Chunks:new()
        chunks:append('foo')
        chunks:append('bar')
        assert.is_equal(#chunks, 2)
        assert.is_string(chunks[1])
        assert.is_string(chunks[2])

        chunks:append('baz', 42, elt.Chunks.CODE)
        assert.is_equal(#chunks, 3)
        assert.is_table(chunks[3])
        assert.is_string(chunks[3][1])
        assert.is_number(chunks[3][2])
        assert.is_equal(chunks[3][3], elt.Chunks.CODE)

        chunks:append('quux', 42, elt.Chunks.RAW)
        assert.is_equal(#chunks, 4)
        assert.is_table(chunks[4])
        assert.is_string(chunks[4][1])
        assert.is_number(chunks[4][2])
        assert.is_equal(chunks[4][3], elt.Chunks.RAW)
    end)

end)


--------------------------------------------------------------------------------
describe('Generator class', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Generator)
        assert.is_function(elt.Generator.new)
        assert.is_function(elt.Generator.generate)
        assert.is_function(elt.Generator.result)
    end)

    it('can create instances with `new`', function()
        local generator = elt.Generator:new()
        assert.is_table(generator)
        assert.is_table(getmetatable(generator))
        assert.is_same(getmetatable(generator), elt.Generator)
    end)

    local plain_text = true -- For clarity in some string.find() calls.
    local generator, chunks

    describe('once created', function()
        before_each(function()
            generator = elt.Generator:new()
            chunks = elt.Chunks:new()
        end)

        it('starts with an empty buffer and result', function()
            assert.is_table(generator.buffer)
            assert.is_same(#generator.buffer, 0)
            local result = generator:result()
            assert.is_same(result, '')
        end)

        it('generates a basic program with empty chunks', function()
            local result = generator:generate(chunks)
            assert.is_not_nil(result:find("local __buffer = ...", 1, plain_text))
            assert.is_not_nil(result:find("return __buffer", 1, plain_text))
        end)

        it('generates a program that produces basic text', function()
            chunks:append([[Bob's "regular" text]])
            local result = generator:generate(chunks)
            local pattern = [[table.insert(__buffer, "Bob's \"regular\" text")]]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('generates a program that inserts code verbatim', function()
            chunks:append('if condition then', 42, chunks.CODE)
            chunks:append('Condition was true')
            chunks:append('end', 44, chunks.CODE)
            local result = generator:generate(chunks)
            local pattern = [[table.insert(__buffer, "Condition was true")]]
            assert.is_not_nil(result:find([=[--[[42]] if condition then]=], 1, plain_text))
            assert.is_not_nil(result:find(pattern, 1, plain_text))
            assert.is_not_nil(result:find([=[--[[44]] end]=], 1, plain_text))
        end)

        it('generates a program that interpolates values', function()
            chunks:append('interpolated', 42, chunks.RAW)
            local result = generator:generate(chunks)
            local pattern = [=[--[[42]] table.insert(__buffer, tostring(interpolated))]=]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('generates a program that interpolates and escapes values', function()
            chunks:append('escaped', 42, chunks.ESCAPE)
            local result = generator:generate(chunks)
            local pattern = [=[--[[42]] table.insert(__buffer, escape(tostring(escaped)))]=]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('has functions that can be overridden', function()
            generator.footer = function(self)
                return self:push('return table.concat(__buffer)\n')
            end
            local result = generator:generate(chunks)
            assert.is_not_nil(result:find("local __buffer = ...", 1, plain_text))
            assert.is_nil(result:find("return __buffer", 1, plain_text))
            assert.is_not_nil(result:find("return table.concat(__buffer)", 1, plain_text))
        end)

    end)

end)


--------------------------------------------------------------------------------
describe('Parser class', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Parser)
        assert.is_function(elt.Parser.new)
        assert.is_function(elt.Parser.wrap_source)
        assert.is_function(elt.Parser.parse)
    end)

    it('can create instances with `new`', function()
        local parser = elt.Parser:new()
        assert.is_table(parser)
        assert.is_table(getmetatable(parser))
        assert.is_same(getmetatable(parser), elt.Parser)
    end)

    it('can wrap strings and arrays of strings in an iterator', function()
        local sources = {
            'first\nsecond\nthird\n',        -- UNIX LF.
            'first\nsecond\nthird',          -- UNIX LF, but no LF at EOF.
            'first\r\nsecond\r\nthird\r\n',  -- DOS CRLF.
            'first\r\nsecond\r\nthird',      -- DOS CRLF, but no CRLF at EOF.
            { 'first', 'second', 'third' },  -- Array of strings.
        }
        for _, source in ipairs(sources) do
            local results = {}
            for line in elt.Parser.wrap_source(source) do
                table.insert(results, line)
            end
            assert.is_same(results, {'first', 'second', 'third'})
        end

        -- Some more tests with empty lines.
        local results = {}
        for line in elt.Parser.wrap_source('1\n\n3\n\n\n') do
            table.insert(results, line)
        end
        assert.is_same(results, {'1', '', '3', '', ''})

        results = {}
        for line in elt.Parser.wrap_source({'1', '', '3', '', ''}) do
            table.insert(results, line)
        end
        assert.is_same(results, {'1', '', '3', '', ''})

        -- Now with "trivial" cases, without multiple lines.
        results = {}
        for line in elt.Parser.wrap_source('') do
            table.insert(results, line)
        end
        assert.is_same(results, {})

        results = {}
        for line in elt.Parser.wrap_source('Example') do
            table.insert(results, line)
        end
        assert.is_same(results, {'Example'})

        results = {}
        for line in elt.Parser.wrap_source({}) do
            table.insert(results, line)
        end
        assert.is_same(results, {})

        results = {}
        for line in elt.Parser.wrap_source({'Example'}) do
            table.insert(results, line)
        end
        assert.is_same(results, {'Example'})
    end)

    local parser

    describe('once created', function()
        before_each(function()
            parser = elt.Parser:new()
        end)

        it('parses an empty string into empty chunks', function()
            local chunks = parser:parse('')
            assert.is_table(chunks)
            assert.is_table(getmetatable(chunks))
            assert.is_same(getmetatable(chunks), elt.Chunks)
            assert.is_same(#chunks, 0)
        end)

        it('parses a simple string into one chunk', function()
            local chunks = parser:parse('hello world')
            assert.is_table(chunks)
            assert.is_table(getmetatable(chunks))
            assert.is_same(getmetatable(chunks), elt.Chunks)
        end)

    end)

end)


--------------------------------------------------------------------------------
