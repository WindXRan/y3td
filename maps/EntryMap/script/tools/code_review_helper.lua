-- 代码审查辅助工具
-- 用于检测混淆变量和常见代码问题

local M = {}

-- 混淆变量模式
local OBUSCATED_PATTERNS = {
    -- 单字符变量（排除循环变量 i, j, k 等）
    { pattern = '^local%s+([a-zA-Z])$', description = '单字符局部变量', exclude = { 'i', 'j', 'k', 'x', 'y', 'z' } },
    -- 双字符大小写混合变量
    { pattern = '\\b([a-z][A-Z])\\b', description = '小写开头后跟大写的双字符变量' },
    { pattern = '\\b([A-Z][a-z])\\b', description = '大写开头后跟小写的双字符变量' },
}

-- 检查单个文件
function M.check_file(file_path)
    local f = io.open(file_path, 'r')
    if not f then return {} end
    
    local content = f:read('*all')
    f:close()
    
    local issues = {}
    local lines = {}
    
    -- 按行分割
    for line in content:gmatch('[^\n]+') do
        table.insert(lines, line)
    end
    
    -- 检查每一行
    for line_num, line in ipairs(lines) do
        for _, pattern_info in ipairs(OBUSCATED_PATTERNS) do
            local matches = {}
            for match in line:gmatch(pattern_info.pattern) do
                -- 检查是否在排除列表中
                local should_exclude = false
                if pattern_info.exclude then
                    for _, excluded in ipairs(pattern_info.exclude) do
                        if match == excluded then
                            should_exclude = true
                            break
                        end
                    end
                end
                
                if not should_exclude then
                    table.insert(matches, match)
                end
            end
            
            if #matches > 0 then
                table.insert(issues, {
                    line = line_num,
                    description = pattern_info.description,
                    matches = table.concat(matches, ', '),
                    content = line
                })
            end
        end
    end
    
    return issues
end

-- 检查目录
function M.check_directory(dir_path)
    local results = {}
    local total_issues = 0
    
    -- 简单的目录遍历（假设没有子目录）
    local cmd = string.format('dir /b /s "%s"', dir_path)
    local handle = io.popen(cmd)
    if handle then
        for file_path in handle:lines() do
            -- 只检查 lua 文件
            if file_path:match('%.lua$') then
                local issues = M.check_file(file_path)
                if #issues > 0 then
                    results[file_path] = issues
                    total_issues = total_issues + #issues
                end
            end
        end
        handle:close()
    end
    
    return results, total_issues
end

-- 输出检查结果
function M.print_results(results)
    print('=' .. string.rep('-', 78) .. '=')
    print('                    代码审查结果')
    print('=' .. string.rep('-', 78) .. '=')
    
    local total_files = 0
    local total_issues = 0
    
    for file_path, issues in pairs(results) do
        total_files = total_files + 1
        print('\n[' .. file_path .. ']')
        print('-' .. string.rep('-', 78))
        
        for _, issue in ipairs(issues) do
            total_issues = total_issues + 1
            print(string.format('  第 %4d 行: %s', issue.line, issue.description))
            print(string.format('            检测到: %s', issue.matches))
            print(string.format('            代码: %s', issue.content))
        end
    end
    
    print('\n' .. '=' .. string.rep('-', 78) .. '=')
    print(string.format('  检查文件数: %d', total_files))
    print(string.format('  发现问题数: %d', total_issues))
    print('=' .. string.rep('-', 78) .. '=')
    
    return total_issues
end

-- 主函数
function M.run(dir_path)
    dir_path = dir_path or 'script'
    print('正在检查目录: ' .. dir_path)
    print()
    
    local results, total = M.check_directory(dir_path)
    M.print_results(results)
    
    return total
end

return M
