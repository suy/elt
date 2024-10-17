require '../tests/luassert-reversed-en'

local elt = require 'elt'

describe('Module basics', function()
    setup(function()
    end)

    it('Has the basics in the module', function()
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

    it('has an append function', function()
        local chunks = elt.Chunks:new()
        chunks:append('foo')
        chunks:append('bar')
        assert.is_equal(#chunks, 2)

        chunks:append('baz', 42, elt.Chunks.CODE)
        assert.is_equal(#chunks, 3)

        assert.is_string(chunks[1])
        assert.is_string(chunks[2])
        assert.is_table(chunks[3])
    end)

end)

