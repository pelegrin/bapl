N = 8 -- кв. доска размеров 8 на 8

function printresult(a)
    for r = 1, N do
        for c = N, 1, -1 do
            if (a[r] == c) then
                io.write("X ")
            else
                io.write("- ")    
            end
        end        
        io.write("\n")        
    end
    io.write("\n")
    io.write("\n")
end

function addqueen(a, n)    
    if (n > N) then
        printresult(a)
    else
        for c = 1, N do
             if (not isunderattac(a, n, c)) then
                a[n] = c
                addqueen(a, n + 1)
             end
        end
    end
end

function isunderattac(a, row, col)        
    step = 1
    for n = row - 1, 1, -1 do
        if col == a[n] + step or col == a[n] - step or col == a[n] then
            return true
        end
        step = step + 1
    end
    return false
end

assert(isunderattac({1}, 2, 1), "same column test failed")
assert(isunderattac({4,3}, 3, 4), "same column test failed")
assert(isunderattac({4,3}, 3, 3), "same column test failed")
assert(isunderattac({1}, 2, 2), "diag test failed")
assert(isunderattac({4,3}, 3, 2), "diag test failed")
assert(isunderattac({2,3}, 3, 4), "diag test failed")

addqueen({}, 1)
