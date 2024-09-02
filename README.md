# kit

**kit** is a zsh based utility designed to help you manage and execute scripts within your projects. It allows you to create and organize scripts, linking them to specific directories or storing them centrally. **kit** enables easy access to relevant scripts based on your current directory, so you don't need to remember their exact locations. With interactive features for searching and selecting scripts, **kit** streamlines your workflow and simplifies script management.

## Features

- **Script Creation:** Easily create new scripts and associate them with specific directories.
- **Script Execution:** Run scripts with additional arguments or flags or execute all scripts associated with the current directory in sequence.
- **Interactive Search:** Search through available scripts interactively and select the one you want to run.

## Prerequisites

Before using **kit**, ensure that the following tools are installed on your system:

- **[jq](https://jqlang.github.io/jq/):** A command-line JSON processor.
- **[fzf](https://github.com/junegunn/fzf):** A command-line fuzzy finder.

## Installation

To start using **kit**, follow these steps:

1. Download the script


```sh
curl https://raw.githubusercontent.com/alicavdar/kit/master/kit.zsh -o ~/kit.zsh 

```

2. Source the script

Add the following line to your `.zshrc` file to source the script whenever you start a new shell session:

```sh
source ~/kit.sh
```


3. Reload your shell

```sh
source ~/.zshrc

```

## Getting Started

Set up **kit** with the necessary configuration:

```sh
kit init
```

Optionally, specify a custom repository path:

```
kit init --repo {PATH}
```

For more details on commands and options, use:

```
kit --help
```
