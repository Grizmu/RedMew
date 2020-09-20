local Public = {}

local function new_module(module_name)
    return {
        name = module_name,
        children = {},
        test_funcs = {},
        tests = nil,
        is_open = true,
        depth = nil,
        count = nil,
        passed = nil
    }
end

local root_module = new_module(nil)
Public.root_module = root_module

local parent_module = nil

local function add_module(module_name, module_func, parent)
    local parent_children = parent.children
    local module = parent_children[module_name]

    if not module then
        module = new_module(module_name)
        parent_children[module_name] = module
    end

    parent_module = module
    module_func()
end

function Public.module(module_name, module_func)
    if type(module_name) ~= 'string' then
        error('module_name must be of type string.')
    end

    if type(module_func) ~= 'function' then
        error('module_func must be of type function.')
    end

    local old_parent = parent_module
    local parent = parent_module or root_module

    add_module(module_name, module_func, parent)

    parent_module = old_parent
end

function Public.test(test_name, test_func)
    if not parent_module then
        error('test can not be declared outisde of a module.')
    end

    if type(test_name) ~= 'string' then
        error('test_name must be of type string.')
    end

    if type(test_func) ~= 'function' then
        error('test_func must be of type function.')
    end

    local test_funcs = parent_module.test_funcs
    if test_funcs[test_name] then
        error(
            table.concat {
                "test '",
                test_name,
                "' already exists, can not have duplicate test names in the same module."
            }
        )
    end

    test_funcs[test_name] = test_func
end

return Public
