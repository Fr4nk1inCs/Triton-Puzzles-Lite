{
  description = "A Nix flake with Torch";

  inputs = {
    # nixpkgs version with torch==2.5.0 and triton==3.1.0
    # nixpkgs.url = "github:NixOS/nixpkgs/2d2a9ddbe3f2c00747398f3dc9b05f7f2ebb0f53";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            cudaSupport = true;
            allowUnfree = true;
          };

          overlays = [
            (final: prev: {
              python312 = prev.python312.override {
                packageOverrides = _: prevPy: {
                  triton-bin = prevPy.triton-bin.overridePythonAttrs {
                    postFixup = ''
                      chmod +x "$out/${prev.python312.sitePackages}/triton/backends/nvidia/bin/ptxas"
                      substituteInPlace $out/${prev.python312.sitePackages}/triton/backends/nvidia/driver.py \
                        --replace \
                          'return [libdevice_dir, *libcuda_dirs()]' \
                          'return [libdevice_dir, "${prev.addDriverRunpath.driverLink}/lib", "${prev.cudaPackages.cuda_cudart}/lib/stubs/"]'
                    '';
                  };
                };
              };
              python312Packages = final.python312.pkgs;
            })
          ];
        };
      in {
        devShell = pkgs.mkShell {
          name = "torch";
          packages = with pkgs; [
            (
              python312.withPackages (ps:
                with ps; [
                  torch-bin
                ])
            )
          ];
        };
      }
    );
}
