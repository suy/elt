require '../tests/luassert-reversed-en'

local elt = require 'elt'

describe('Module basics', function()
    setup(function()
    end)

    it('Has the basics in the module', function()
        assert.is_string(elt._COPYRIGHT)
        assert.is_string(elt._DESCRIPTION)
        assert.is_string(elt._VERSION)

        assert.is_table(elt.Generator)
        assert.is_table(elt.Parser)

        assert.is_function(elt.compile)
        assert.is_function(elt.render)
    end)
end)

