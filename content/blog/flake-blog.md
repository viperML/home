---
title: "Static blog with Hugo and Nix flakes"
image: "images/post/daniele-buso-qzUenL35ZYw-unsplash.jpg"
date: 2022-01-05T19:53:13Z
author: "Fernando"
tags: ["Nix"]
categories: ["Linux"]
draft: false
---

In this post, I want to show you how Nix can be used in a development environment to build this simple webpage.

## Hugo

[Hugo](https://gohugo.io/) is a static site generator written in Go. From a users's perspective, you can simply select a template and a written text with no formatting, and it will generate all the files required for the website, including all the HTML, CSS styles, JS scripts. These written input is in form of Markdown, which is uses simple syntax to format the text, and can be edited with any text editor.

`````md
# This is a title in Markdown!

## and a subtitle...

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris non consectetur massa, quis egestas est.

- This
- is
- a list

```bash
echo -e "And this is a codes snippet\n"
```
`````

Hugo templates can be easily found with a quick search in Google, and usually have a specific proyect layout (where to put and format your Markdown files), and require to have the theme repo cloned in the project folder.

Once your project is ready, building the site is as simple as:

```bash
hugo
# Or to get a live reloading preview in your browser:
hugo server
```

This will generate all the files required for the website, rendering out the details for the non web developer like me.

## Nix

Enter the Nix questions. Which version of hugo was used to build the site? What any other dependencies, like the theme, how much do we need from the user environment? Can we fully recreate the static website from another computer?

If properly configured, Nix can solve these problems, by using the (experimental) feature called **flakes**.

On a high level, the flake will provide an interface for our:

- Inputs: our source files, the template and the package dependencies (hugo)
- Output: the static files generated

The basic boilerplate for a flake can be as follows:

```nix
{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils-plus.url = github:gytis-ivaskevicius/flake-utils-plus;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils-plus, ... }:
    flake-utils-plus.lib.mkFlake {
      inherit self inputs;

      outputsBuilder = (channels: {

        # Our outputs start here
        # my-awesome-output = foo;

      });
    };
}
```

The flake syntax define an attribute set `{ inputs = { ... }, outputs = { ... } }`, for which the nix command will recognize the name of the attributes. For example, in inputs, we define `<my input name>.url = ` to declare any number of inputs. Outputs is a functions, which defines how our outputs must be built, given the inputs that are passed in the arguments. The [flake-utils-plus](https://github.com/gytis-ivaskevicius/nixfiles) library is an amazing piece of software that allows some abstraction and reuse of flake operations. For example, outputs are split into different systems, such as `x86_64-linux` or `aarch64-linux` (which are not the same because they use differently packages), so we would have to specify for each architecture. `outputsBuilder` automates this process for us.

Finally, we can put our hugo blog as a output:


```nix
{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils-plus.url = github:gytis-ivaskevicius/flake-utils-plus;

    bookworm = {
      url = github:gethugothemes/bookworm-light;
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, flake-utils-plus, ... }:
    flake-utils-plus.lib.mkFlake {
      inherit self inputs;

      outputsBuilder = (channels:
        let
          pkgs = channels.nixpkgs;
        in {

          blog = pkgs.stdenv.mkDerivation {
            name = "blog";
            src = ./.;
            buildPhase = ''
              mkdir -p themes
              ln -s ${inputs.bookworm} themes/bookworm
              ${pkgs.hugo}/bin/hugo --minify
            '';
            installPhase = ''
              cp -r public $out
            '';
            meta = with pkgs.lib; {
              description = "My awesome webpage";
              license = licenses.cc-by-nc-sa-40;
              platforms = platforms.all;
            };
          };

        });
    };
}
```

Our `blog` output will be a derivation. You can think of a derivation as a folder which holds any stuff, and built with Nix. In this context, `blog` will be a derivation sitting in `/nix/store/<hash>-blog`, and it will contain our static website. To build it, we pass some basic information, such as `name`, `src` or `meta`, and then define the build and install phases. These are just bash snippets, which run in a sandboxed environment (no packages, no internet, etc). The rest is specfic to this project: we have to bring the template that we defined in our `inputs`. The `${ }` syntax can be used to reference a derivation (a folder!), so calling `${inputs.bookworm}` will just return the path to the theme folder. In the same way `${pkgs.hugo}` is the folder in which the hugo binary is installed, so we just have to add the relative path to the binary.

So when we call `nix build <the path to the project>#blog`, what Nix will do is read the `flake.lock` file, pull the exact dependencies, and build the derivation. As the derivations ( `${pkgs. ...}` ), are always subsituted for the same value, given the same lockfile, we are guaranteed to have the same output out of this flake, without taking into account any user environment, linux version, date, etc.

If you don't believe this, you can checkout this blog's repository and go to my last commit before writing this post. If all the sources are still available, you will get a exact copy of the website at this time:

```bash
git clone https://github.com/viperML/home && cd home
git checkout 416172a7da5129347fa95c166120a34252cc7815
nix build .#home.x86_64-linux
ls result
# or to get a live-reloading local server
nix run .#serve
```


## GitHub pages

To finish it up, we can deploy our website for free using [GitHub pages](https://docs.github.com/en/pages), for which we just have to provide our static files, and github servers will do the rest, automatically. We don't even have to manually build the website, as we can also keep it in the github ecosystem with [GitHub Actions](https://docs.github.com/en/actions/quickstart), a integration tool that will build the website for us. As we saw previously, if we use nix to build the website, the output will be the same, be it on our PC or in the cloud.
