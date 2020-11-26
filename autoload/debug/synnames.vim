vim9script

def debug#synnames#main(count: number) #{{{1
    if count != 0
        var name = Synnames()->get(count - 1, '')
        if !empty(name)
            exe 'syntax list ' .. name
        endif
    else
        echo Synnames()->join()
    endif
enddef

def Synnames(): list<string> #{{{1
    # The syntax  element under  the cursor  is part  of a  group, which  can be
    # contained in another one, and so on.
    #
    # This imbrication  of syntax groups  can be  seen as a  stack. `synstack()`
    # returns  the list  of IDs  for  all syntax  groups  in the  stack, at  the
    # position given.
    #
    # They are sorted from the outermost syntax group, to the innermost.
    #
    # The last one is what `synID()` returns.
    return synstack('.', col('.'))->map({_, v -> synIDattr(v, 'name')})->reverse()
enddef

