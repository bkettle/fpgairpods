# FPGAirPods

This is a final project for MIT 6.111 Introductory Digital Systems Laboratory by Gokul Kolady, Niko Ramirez, and Ben Kettle. Our goal is to emulate noise cancelling headphones (ie, AirPods) by implementing an Active Noise Cancellation algorithm. 


## Setting up the Vivado Project
Vivado is funky with source control so this uses the process outlined [here](http://www.fpgadeveloper.com/2014/08/version-control-for-vivado-projects.html) to try to make it neater. Basically, it just means keeping all the source files separate, then generating a script with vivado that allows you to rebuild the project later. 

### Setting up local vivado project
There isn't a vivado project stored in the git repo, just the files needed to generate one. To generate, open vivado, click "window" at the top, then "tcl console". 

### Creating new files
Rather than creating files inside the Vivado project directory tree like we did in the labs, we will put them inside of the `vivado/hdl` directory tree---so we should never save anything to the tree that vivado generates. So when you create a new file, either create it on the command line or something, or just manually specify the location in Vivado to make sure it goes in the `vivado/hdl` folder. 

## Using git
I think the best way to work on different things simultaneously is to have different branches and then once everything works to merge them into `main`. So, to do this, first clone the repo to your computer. You should be on the `main` branch by default, so to start working on a new module or other feature do `git checkout -b [feature-name]`. This creates a new branch (`-b <branch-name>`), equivalent to `git branch <branch-name>`, then checks out that branch, switching your local directory structure to be everything in that branch. Now, you can make whatever changes you want and it won't affect the working code on the `main` branch. 

### Saving changes
Once you make some changes and want to commit them, you first have to export a new script that can be used to regenerate the project. To do this, use the "tcl console" tab at the bottom of Vivado and type `cd <path-to-git-repo/vivado>` then tell vivado to generate the script with `write_project_tcl -force generate.tcl`

Then, use `git add .` to _stage_ everything you changed. Then, do `git commit -m <summary of changes>` to commit all those changes. Finally, to upload to the github again, do `git push origin <branch-name>` where `branch-name` is the one that you did earlier with `git checkout -b`. 
