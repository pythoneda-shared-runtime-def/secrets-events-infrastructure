# flake.nix
#
# This file packages pythoneda-shared-runtime/secrets-events-infrastructure as a Nix flake.
#
# Copyright (C) 2024-today rydnr's pythoneda-shared-runtime/secrets-events-infrastructure
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
{
  description =
    "Nix flake for pythoneda-shared-runtime/secrets-events-infrastructure";
  inputs = rec {
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
    pythoneda-shared-pythonlang-banner = {
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:pythoneda-shared-pythonlang-def/banner/0.0.78";
    };
    pythoneda-shared-pythonlang-domain = {
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pythoneda-shared-pythonlang-banner.follows =
        "pythoneda-shared-pythonlang-banner";
      url = "github:pythoneda-shared-pythonlang-def/domain/0.0.113";
    };
    pythoneda-shared-pythonlang-infrastructure = {
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pythoneda-shared-pythonlang-banner.follows =
        "pythoneda-shared-pythonlang-banner";
      inputs.pythoneda-shared-pythonlang-domain.follows =
        "pythoneda-shared-pythonlang-domain";
      url = "github:pythoneda-shared-pythonlang-def/infrastructure/0.0.89";
    };
    pythoneda-shared-runtime-secrets-events = {
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pythoneda-shared-pythonlang-banner.follows =
        "pythoneda-shared-pythonlang-banner";
      inputs.pythoneda-shared-pythonlang-domain.follows =
        "pythoneda-shared-pythonlang-domain";
      url = "github:pythoneda-shared-runtime-def/secrets-events/0.0.13";
    };
  };
  outputs = inputs:
    with inputs;
    flake-utils.lib.eachDefaultSystem (system:
      let
        org = "pythoneda-shared-runtime";
        repo = "secrets-events-infrastructure";
        version = "0.0.6";
        sha256 = "1rrfaiwg5zyinw9yk3044gpg72mlxprmhgssah8fg0kn4ch6lc0x";
        pname = "${org}-${repo}";
        pythonpackage = "pythoneda.shared.runtime.secrets.events.infrastructure";
        package = builtins.replaceStrings [ "." ] [ "/" ] pythonpackage;
        description =
          "Shared kernel for pythoneda-shared-runtime/secrets-events-infrastructure";
        license = pkgs.lib.licenses.gpl3;
        homepage = "https://github.com/${org}/${repo}";
        maintainers = with pkgs.lib.maintainers;
          [ "rydnr <github@acm-sl.org>" ];
        archRole = "E";
        space = "D";
        layer = "I";
        nixpkgsVersion = builtins.readFile "${nixpkgs}/.version";
        nixpkgsRelease =
          builtins.replaceStrings [ "\n" ] [ "" ] "nixpkgs-${nixpkgsVersion}";
        shared = import "${pythoneda-shared-pythonlang-banner}/nix/shared.nix";
        pkgs = import nixpkgs { inherit system; };
        pythoneda-shared-runtime-secrets-events-infrastructure-for = { python
          , pythoneda-shared-runtime-secrets-events, pythoneda-shared-pythonlang-domain
          , pythoneda-shared-pythonlang-infrastructure }:
          let
            pnameWithUnderscores =
              builtins.replaceStrings [ "-" ] [ "_" ] pname;
            pythonVersionParts = builtins.splitVersion python.version;
            pythonMajorVersion = builtins.head pythonVersionParts;
            pythonMajorMinorVersion =
              "${pythonMajorVersion}.${builtins.elemAt pythonVersionParts 1}";
            wheelName =
              "${pnameWithUnderscores}-${version}-py${pythonMajorVersion}-none-any.whl";
          in python.pkgs.buildPythonPackage rec {
            inherit pname version;
            projectDir = ./.;
            pyprojectTomlTemplate = ./templates/pyproject.toml.template;
            pyprojectToml = pkgs.substituteAll {
              authors = builtins.concatStringsSep ","
                (map (item: ''"${item}"'') maintainers);
              desc = description;
              inherit homepage package pname pythonMajorMinorVersion pythonpackage version;
              dbusNext = python.pkgs.dbus-next.version;
              pythonedaSharedPythonlangDomain =
                pythoneda-shared-pythonlang-domain.version;
              pythonedaSharedPythonlangInfrastructure =
                pythoneda-shared-pythonlang-infrastructure.version;
              pythonedaSharedRuntimeSecretsEvents =
                pythoneda-shared-runtime-secrets-events.version;
              src = pyprojectTomlTemplate;
            };
            src = pkgs.fetchFromGitHub {
              owner = org;
              rev = version;
              inherit repo sha256;
            };

            format = "pyproject";

            nativeBuildInputs = with python.pkgs; [ pip poetry-core ];
            propagatedBuildInputs = with python.pkgs; [
              dbus-next
              pythoneda-shared-runtime-secrets-events
              pythoneda-shared-pythonlang-domain
              pythoneda-shared-pythonlang-infrastructure
            ];

            pythonImportsCheck = [ pythonpackage ];

            unpackPhase = ''
              command cp -r ${src} .
              sourceRoot=$(command ls | command grep -v env-vars)
              command chmod +w $sourceRoot
              command cp ${pyprojectToml} $sourceRoot/pyproject.toml
            '';

            postInstall = with python.pkgs; ''
              command pushd /build/$sourceRoot
              for f in $(command find . -name '__init__.py'); do
                if [[ ! -e $out/lib/python${pythonMajorMinorVersion}/site-packages/$f ]]; then
                  command cp $f $out/lib/python${pythonMajorMinorVersion}/site-packages/$f;
                fi
              done
              command popd
              command mkdir -p $out/dist $out/deps/flakes $out/deps/nixpkgs
              command cp dist/${wheelName} $out/dist
              for dep in ${pythoneda-shared-runtime-secrets-events} ${pythoneda-shared-pythonlang-domain} ${pythoneda-shared-pythonlang-infrastructure}; do
                command cp -r $dep/dist/* $out/deps || true
                if [ -e $dep/deps ]; then
                  command cp -r $dep/deps/* $out/deps || true
                fi
                METADATA=$dep/lib/python${pythonMajorMinorVersion}/site-packages/*.dist-info/METADATA
                NAME="$(command grep -m 1 '^Name: ' $METADATA | command cut -d ' ' -f 2)"
                VERSION="$(command grep -m 1 '^Version: ' $METADATA | command cut -d ' ' -f 2)"
                command ln -s $dep $out/deps/flakes/$NAME-$VERSION || true
              done
              for nixpkgsDep in ${dbus-next}; do
                METADATA=$nixpkgsDep/lib/python${pythonMajorMinorVersion}/site-packages/*.dist-info/METADATA
                NAME="$(command grep -m 1 '^Name: ' $METADATA | command cut -d ' ' -f 2)"
                VERSION="$(command grep -m 1 '^Version: ' $METADATA | command cut -d ' ' -f 2)"
                command ln -s $nixpkgsDep $out/deps/nixpkgs/$NAME-$VERSION || true
              done
            '';

            meta = with pkgs.lib; {
              inherit description homepage license maintainers;
            };
          };
      in rec {
        defaultPackage = packages.default;
        devShells = rec {
          default = pythoneda-shared-runtime-secrets-events-infrastructure-python312;
          pythoneda-shared-runtime-secrets-events-infrastructure-python39 =
            shared.devShell-for {
              banner = "${
                  pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python39
                }/bin/banner.sh";
              extra-namespaces = "";
              nixpkgs-release = nixpkgsRelease;
              package =
                packages.pythoneda-shared-runtime-secrets-events-infrastructure-python39;
              python = pkgs.python39;
              pythoneda-shared-pythonlang-banner =
                pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python39;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python39;
              inherit archRole layer org pkgs repo space;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python310 =
            shared.devShell-for {
              banner = "${
                  pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python310
                }/bin/banner.sh";
              extra-namespaces = "";
              nixpkgs-release = nixpkgsRelease;
              package =
                packages.pythoneda-shared-runtime-secrets-events-infrastructure-python310;
              python = pkgs.python310;
              pythoneda-shared-pythonlang-banner =
                pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python310;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python310;
              inherit archRole layer org pkgs repo space;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python311 =
            shared.devShell-for {
              banner = "${
                  pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python311
                }/bin/banner.sh";
              extra-namespaces = "";
              nixpkgs-release = nixpkgsRelease;
              package =
                packages.pythoneda-shared-runtime-secrets-events-infrastructure-python311;
              python = pkgs.python311;
              pythoneda-shared-pythonlang-banner =
                pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python311;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python311;
              inherit archRole layer org pkgs repo space;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python312 =
            shared.devShell-for {
              banner = "${
                  pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python312
                }/bin/banner.sh";
              extra-namespaces = "";
              nixpkgs-release = nixpkgsRelease;
              package =
                packages.pythoneda-shared-runtime-secrets-events-infrastructure-python312;
              python = pkgs.python312;
              pythoneda-shared-pythonlang-banner =
                pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python312;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python312;
              inherit archRole layer org pkgs repo space;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python313 =
            shared.devShell-for {
              banner = "${
                  pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python313
                }/bin/banner.sh";
              extra-namespaces = "";

              nixpkgs-release = nixpkgsRelease;
              package =
                packages.pythoneda-shared-runtime-secrets-events-infrastructure-python313;
              python = pkgs.python313;
              pythoneda-shared-pythonlang-banner =
                pythoneda-shared-pythonlang-banner.packages.${system}.pythoneda-shared-pythonlang-banner-python313;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python313;
              inherit archRole layer org pkgs repo space;
            };
        };
        packages = rec {
          default = pythoneda-shared-runtime-secrets-events-infrastructure-python312;
          pythoneda-shared-runtime-secrets-events-infrastructure-python39 =
            pythoneda-shared-runtime-secrets-events-infrastructure-for {
              python = pkgs.python39;
              pythoneda-shared-runtime-secrets-events =
                pythoneda-shared-runtime-secrets-events.packages.${system}.pythoneda-shared-runtime-secrets-events-python39;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python39;
              pythoneda-shared-pythonlang-infrastructure =
                pythoneda-shared-pythonlang-infrastructure.packages.${system}.pythoneda-shared-pythonlang-infrastructure-python39;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python310 =
            pythoneda-shared-runtime-secrets-events-infrastructure-for {
              python = pkgs.python310;
              pythoneda-shared-runtime-secrets-events =
                pythoneda-shared-runtime-secrets-events.packages.${system}.pythoneda-shared-runtime-secrets-events-python310;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python310;
              pythoneda-shared-pythonlang-infrastructure =
                pythoneda-shared-pythonlang-infrastructure.packages.${system}.pythoneda-shared-pythonlang-infrastructure-python310;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python311 =
            pythoneda-shared-runtime-secrets-events-infrastructure-for {
              python = pkgs.python311;
              pythoneda-shared-runtime-secrets-events =
                pythoneda-shared-runtime-secrets-events.packages.${system}.pythoneda-shared-runtime-secrets-events-python311;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python311;
              pythoneda-shared-pythonlang-infrastructure =
                pythoneda-shared-pythonlang-infrastructure.packages.${system}.pythoneda-shared-pythonlang-infrastructure-python311;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python312 =
            pythoneda-shared-runtime-secrets-events-infrastructure-for {
              python = pkgs.python312;
              pythoneda-shared-runtime-secrets-events =
                pythoneda-shared-runtime-secrets-events.packages.${system}.pythoneda-shared-runtime-secrets-events-python312;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python312;
              pythoneda-shared-pythonlang-infrastructure =
                pythoneda-shared-pythonlang-infrastructure.packages.${system}.pythoneda-shared-pythonlang-infrastructure-python312;
            };
          pythoneda-shared-runtime-secrets-events-infrastructure-python313 =
            pythoneda-shared-runtime-secrets-events-infrastructure-for {
              python = pkgs.python313;
              pythoneda-shared-runtime-secrets-events =
                pythoneda-shared-runtime-secrets-events.packages.${system}.pythoneda-shared-runtime-secrets-events-python313;
              pythoneda-shared-pythonlang-domain =
                pythoneda-shared-pythonlang-domain.packages.${system}.pythoneda-shared-pythonlang-domain-python313;
              pythoneda-shared-pythonlang-infrastructure =
                pythoneda-shared-pythonlang-infrastructure.packages.${system}.pythoneda-shared-pythonlang-infrastructure-python313;
            };
        };
      });
}
