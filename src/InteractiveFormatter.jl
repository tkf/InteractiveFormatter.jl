module InteractiveFormatter

using JuliaFormatter: format_text
using REPL: LineEdit, LineEditREPL, REPL
using REPL.LineEdit: InputAreaState, edit_insert, input_string

function format_prompt(s, _...)
    code = try
        format_text(String(take!(copy(LineEdit.buffer(s)))))
    catch err
        println(stderr)
        @error "Error in `format_prompt`" exception = (err, catch_backtrace())
        println(stderr)
        LineEdit.refresh_line(s)
        return
    end
    take!(LineEdit.buffer(s))  # empty prompt
    edit_insert(s, code)
end

"""
    afterreplinit(f)

Like `atreplinit` but triggers `f` even after REPL is initialized when
it is called.
"""
function afterreplinit(f)
    # See: https://github.com/JuliaLang/Pkg.jl/blob/v1.0.2/src/Pkg.jl#L338
    function wrapper(repl)
        if isinteractive() && repl isa REPL.LineEditREPL
            f(repl)
        end
    end
    if isdefined(Base, :active_repl)
        wrapper(Base.active_repl)
    else
        atreplinit() do repl
            @async begin
                wait_repl_interface(repl)
                wrapper(repl)
            end
        end
    end
end

function wait_repl_interface(repl)
    for _ in 1:20
        try
            repl.interface.modes[1].keymap_dict
            return
        catch
        end
        sleep(0.05)
    end
end

function init_repl(repl)
    formatter_keymap = Dict{Any,Any}("^V" => format_prompt)

    main_mode = repl.interface.modes[1]
    main_mode.keymap_dict = LineEdit.keymap_merge(
        main_mode.keymap_dict,
        LineEdit.keymap([formatter_keymap]),
    )
end
# See: https://github.com/JuliaInterop/RCall.jl/blob/master/src/RPrompt.jl

function __init__()
    afterreplinit(init_repl)
end

end # module
