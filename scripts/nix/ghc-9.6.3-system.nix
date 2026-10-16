{ lib, stdenv }:

stdenv.mkDerivation {
  name = "ghc-9.6.3-system";
  version = "9.6.3";

  src = null;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib
    
    # Symlink to system GHC installed via ghcup
    ln -s /Users/elliot/.ghcup/bin/ghc $out/bin/ghc
    ln -s /Users/elliot/.ghcup/bin/ghc-pkg $out/bin/ghc-pkg
    ln -s /Users/elliot/.ghcup/bin/haddock $out/bin/haddock
    ln -s /Users/elliot/.ghcup/bin/hp2ps $out/bin/hp2ps
    ln -s /Users/elliot/.ghcup/bin/hsc2hs $out/bin/hsc2hs
    ln -s /Users/elliot/.ghcup/bin/runghc $out/bin/runghc
    ln -s /Users/elliot/.ghcup/bin/runhaskell $out/bin/runhaskell
    
    # Copy GHC lib directory
    if [ -d /Users/elliot/.ghcup/ghc/9.6.3/lib ]; then
      cp -r /Users/elliot/.ghcup/ghc/9.6.3/lib/* $out/lib/
    fi
  '';

  meta = {
    description = "System GHC 9.6.3 installed via ghcup";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.darwin;
  };
}
