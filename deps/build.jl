using WinRPM, SHA, Compat
WinRPM.update()

# update julia's gcc dlls
if is_windows()
    winrpm_bin = joinpath(WinRPM.installdir, "usr", Sys.MACHINE,
        "sys-root", "mingw", "bin")
    dlls = ["libgfortran-4", "libquadmath-0", "libstdc++-6", "libwinpthread-1",
        "libssp-0", Compat.Sys.WORD_SIZE==32 ? "libgcc_s_sjlj-1" : "libgcc_s_seh-1"]
    dlls_to_download = Compat.String[]
    for lib in dlls
        if !isfile(joinpath(winrpm_bin, lib * ".dll"))
            push!(dlls_to_download, replace(lib, "-", ""))
        end
        # try to clean up -copy remnants
        if isfile(joinpath(JULIA_HOME, lib * "-copy.dll"))
            try
                rm(joinpath(JULIA_HOME, lib * "-copy.dll"))
            end
        end
    end
    if !isempty(dlls_to_download)
        WinRPM.install(dlls_to_download; yes = true)
    end
    dlls_to_update = Compat.String[]
    for lib in dlls
        local sha_current, sha_new
        if isfile(joinpath(JULIA_HOME, lib * ".dll"))
            open(joinpath(JULIA_HOME, lib * ".dll")) do f
                sha_current = sha256(f)
            end
        else
            sha_current = UInt8[]
        end
        open(joinpath(winrpm_bin, lib * ".dll")) do f
            sha_new = sha256(f)
        end
        if sha_current != sha_new
            push!(dlls_to_update, lib)
        end
    end
    if !isempty(dlls_to_update)
        try
            for lib in dlls_to_update
                # it's possible to move an in-use dll and put a new file where
                # it used to be, but not delete or overwrite it in-place?
                if isfile(joinpath(JULIA_HOME, lib * ".dll"))
                    mv(joinpath(JULIA_HOME, lib * ".dll"), joinpath(JULIA_HOME, lib * "-copy.dll"))
                end
                cp(joinpath(winrpm_bin, lib * ".dll"), joinpath(JULIA_HOME, lib * ".dll"))
            end
            warn("Updated Julia's gcc dlls, you may need to restart Julia for some WinRPM packages to work.")
        catch err
            buf = PipeBuffer()
            showerror(buf, err)
            warn("Could not update Julia's gcc dlls, some WinRPM packages may not work.\n" *
                "Error was: $(readstring(buf))\n" *
                "Try running Julia as administrator and calling `Pkg.build(\"WinRPM\")`.")
        end
    end
end
