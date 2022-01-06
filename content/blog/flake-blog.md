---
title: "Static blog with Hugo and Nix flakes"
image: "images/post/daniele-buso-qzUenL35ZYw-unsplash.jpg"
date: 2022-01-06T13:27:19Z
author: "Fernando"
tags: ["Nix"]
categories: ["Linux"]
draft: false
---

By using this blog as an example, I want to show you how you can use nix flakes for your project. Flakes are (at the time of writing) a experimental feature in nix, but it is designed to improve the user experience. Nix expressions can be pure, in the sense that the same inputs will give the same outputs. What flakes can solve is properly defining these inputs, sandboxing your build environments, as well as providing a unified interface for flake-based projects, . If you don't know what Nix is, I wrote a post [here](https://ayats.org/blog/nix-intro).

## Hugo

[Hugo](https://gohugo.io/) is a static site generator written in Go. From a users's perspective, you can simply select a template and a written text with no formatting, and it will generate all the files required for the website, including all the HTML, CSS styles, JS scripts. The written input is in form of Markdown (`my-post.md`) files, which use simple syntax to format the text, and can be edited with any text editor.

`````markdown
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

Hugo templates can be easily found with a quick search in Google, and usually have a specific project layout (where to put and format your markdown files), and may require to have the theme repo cloned in the project folder.

Once your project is ready, building the site is as simple as:

```bash
hugo
# Or to get a live reloading preview in your browser:
hugo server
```

This will generate all the files required for the website, rendering out the details for the non web developer like me.

## Nix

Enter the Nix questions. Which version of hugo was used to build the site? What any other dependencies, like the theme, how much do we need from the user environment? Can we fully recreate the static website from another computer?
If properly configured, Nix can solve these problems, with the help of **flakes**.

On a high level, a `flake.nix` file will provide an interface for our:

- Inputs: our source files, the template and the package dependencies (hugo)
- Output: the static files generated

The basic boilerplate for a flake can be as follows:

```nix
# flake.nix at project root
{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils-plus.url = github:gytis-ivaskevicius/flake-utils-plus;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils-plus, ... }:
    flake-utils-plus.lib.mkFlake {
      inherit self inputs;

      # Our system-independent outputs go here
      # E.g. NixOS configurations

      outputsBuilder = (channels: {

        # Our system-dependent outputs go here
        # E.g. packages, shell environments, etc

      });
    };
}
```

The flake syntax require you to put an attribute set `{ inputs = { ... }, outputs = { ... } }`, such that:

- `inputs` will contain url's other flakes or non-flake resources (such as any git repo). On the first call to the flake, these inputs will be **"locked"**: nix will pull the latest or specified version and write them to a `flake.lock` (similar to lock files in node, cargo, go, etc).
- `inputs.flake-utils-plus` is a library that provides some common functions used in flakes, that help us save some lines ([GitHub link](https://github.com/gytis-ivaskevicius/flake-utils-plus)).
- `output` is a function, that that can take as input the `inputs` attribute. As a result, it returns another attribute set that contains our outputs. These outputs can take many forms, but we discuss our output in the next section.

We can set our blog output as follows:

```nix
{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils-plus.url = github:gytis-ivaskevicius/flake-utils-plus;

    # Website template
    bookworm = {
      url = github:gethugothemes/bookworm-light;
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils-plus, ... }:
    flake-utils-plus.lib.mkFlake {
      inherit self inputs;

      outputsBuilder = (channels:
        let
          pkgs = channels.nixpkgs; # quicker alias
        in {

          blog = pkgs.stdenv.mkDerivation {
            name = "blog"; # our package name, irrelevant in this case
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

We build our `blog` output with the function `mkDerivation`. You can think of a derivation, as a folder which holds any stuff, and built with Nix. So, the `blog` derivation will be a folder sitting in `/nix/store/<hash>-blog`, and it will contain all the contents of our static website. `mkDerivation` accepts some basic metadata, such as `name`, `src` or `meta`. The `xxxPhase` are just bash snippets, which run in a sandboxed environment (no packages, no internet, etc) to build our package. The build process is specific to this package, but the main idea still holds: we want to put our built website into `$out` (which is the path to the derivation, substituted by Nix). To do so, we call our hugo binary. Its location is in `/nix/store/<hash>-hugo-<version>/bin/hugo` (according to the inputs), and this path can be called just by using `${pkgs.hugo}/bin/hugo`. In the same fashion, our template called `bookworm` is also a derivation (a folder!) sitting in the nix store, that we can call by using `${inputs.bookworm}`.

Once our flake is defined, `nix build <the path to the project>#blog` will read the `flake.nix`, read the `flake.lock` with the specific versions for our inputs, and begin the build process for our derivation. Nix will also put a symlink to our latest build under `./result`.

If you want to try for yourself, you can checkout this blog's repository and go to my last commit before writing this post. If all the sources are still available, you will get a exact copy of the website at that time:

```bash
git clone https://github.com/viperML/home
cd home
git checkout 416172a7da5129347fa95c166120a34252cc7815
nix build .#home.x86_64-linux
ls ./result # index.html, ...
# or to get a live-reloading local server
nix run .#serve
```


## GitHub pages

To deploy the website, there are many solutions, but the quickest one was to use GitHub pages for our GitHub repo. In a nutshell:

1. Push the static website to a specific branch
2. Github will host deploy it for you
3. You can even bring your own domain name, instead of the default `XXX.github.io`

You can check out the [quickstart guide](https://docs.github.com/en/pages/quickstart) for generic guide, but to use our nix infrastructure, we can use "GitHub Actions", which will set up a virtual machine to build or project on each push.

```yaml
name: Deploy to GH pages

on:
  push:
    branches:
      - bookworm

jobs:
  deploy:
    name: Deploy job
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: 0 # Nix Flakes doesn't work on shallow clones
      - name: Install nix with flakes
        uses: cachix/install-nix-action@v16
        with:
          install_url: https://github.com/numtide/nix-unstable-installer/releases/download/nix-2.6.0pre20211228_ed3bc63/install
          extra_nix_config: |
            experimental-features = nix-command flakes
      - name: Build static site
        run: nix build .#home.x86_64-linux
      - name: Deploy to gh-pages branch
        uses: peaceiris/actions-gh-pages@v3
        if: github.ref == 'refs/heads/bookworm'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./result
```

This GiHub action will install Nix, build the website, and copy the `./result` (symlink to the built derivation) into a new branch called `gh-pages`. From there it will be automatically deployed.

## Finale

I hope this post has been useful to demistify Nix and flakes, and to give you ideas on how to integrate it in your project.


## Further reading

- [Yannik Sander - Building with Nix Flakes for, eh .. reasons!](https://blog.ysndr.de/posts/internals/2021-01-01-flake-ification/)
- [Eelco Dolstra - Nix Flakes: An introduction and tutorial](https://www.tweag.io/blog/2020-05-25-flakes/)
- [Alexander Bantyev - Practical Nix Flakes](https://serokell.io/blog/practical-nix-flakes)
-
