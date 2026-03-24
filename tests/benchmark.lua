-- benchmark.lua

local function bench_template(template_str, data)
    -- Simulate template rendering and measure time
    local start_time = os.clock()
    -- Here you would use a template engine to render the template with the data
    -- For demonstration, we will simulate the rendering duration based on string length
    local render_time = #template_str / 1e6  -- Simulate time complexity based on template size
    local end_time = os.clock()
    return end_time - start_time + render_time
end

local test_templates = {
    { name = "Simple Template", template = "Hello, {{name}}!", data = {name = "World"} },
    { name = "Moderate Template", template = "<div>{{name}}</div><p>{{message}}</p>", data = {name = "Alice", message = "Welcome!"} },
    { name = "Complex Template", template = "<ul>{{#each items}}<li>{{this}}</li>{{/each}}</ul>", data = {items = {"Item 1", "Item 2", "Item 3"}} },
    -- More complex templates can be added here
}

local results = {}

for _, test in ipairs(test_templates) do
    local time_taken = bench_template(test.template, test.data)
    table.insert(results, {name = test.name, time = time_taken})
end

-- Output benchmark results
for _, result in ipairs(results) do
    print(string.format("Benchmark for %s: %.6f seconds", result.name, result.time))
end
