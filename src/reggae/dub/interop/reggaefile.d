/**
   Creates (maybe) a default reggaefile for a dub project.
*/
module reggae.dub.interop.reggaefile;


import reggae.from;


void maybeCreateReggaefile(T)(auto ref T output,
                              in from!"reggae.options".Options options)
{
    import std.file: exists;

    if(options.isDubProject && !options.reggaeFilePath.exists) {
        createReggaefile(output, options);
    }
}

// default build for a dub project when there is no reggaefile
private void createReggaefile(T)(auto ref T output,
                                 in from!"reggae.options".Options options)
{
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.stdio: File;
    import std.regex: regex, replaceFirst;

    output.log("Creating reggaefile.d from dub information");
    auto file = File(buildPath(options.projectPath, "reggaefile.d"), "w");

    file.writeln(q{
        import reggae;
        alias buildTarget = dubDefaultTarget!(); // dub build
        alias testTarget = dubTestTarget!();     // dub test (=> ut[.exe])
        version (Windows) {
            // Windows: extra `ut` convenience alias for `ut.exe`
            alias utTarget = phony!("ut", "", testTarget);
            mixin build!(buildTarget, optional!testTarget,
                         optional!utTarget);
        } else {
            mixin build!(buildTarget, optional!testTarget);
        }
    }.replaceFirst(regex(`^        `), ""));
}
