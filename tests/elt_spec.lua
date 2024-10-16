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
    it('is a table with a metatable', function()
        assert.is_table(elt.Chunks)
        local mt = getmetatable(elt.Chunks)
        assert.is_table(mt)
        assert.is_function(mt.__call)
    end)

    it('can be created with the call operator', function()
        local chunks = elt.Chunks()
        assert.is_table(chunks)
        assert.is_table(getmetatable(chunks))
    end)

    it('has an append function', function()
        local chunks = elt.Chunks()
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

