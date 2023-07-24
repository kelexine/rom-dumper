# Rom-dumper
This is just a simple GitHub workflow that takes the link to your stock rom in .zip
format, extract all the files then pushes them to the release page.
# Does It Actually Work
Yes it works, i have tested it personally with 4 different links.
This does not garantee that it will definitely work for you especially if your device
super.img is bigger than 2G when compressed, this is as a limitation from GitHub.

# What Actually Happens 
when you enter your rom direct download link in .zip format and other details
it first off sets up an Ubuntu server, then downloads the rom and extracts
the whole files into a single directory, it then compresses the super.img using xz compression method.
This us because super.img files tends to be larger than 2G which will not upload there by 
making the whole process fail.

# What Doesn't Work
For now it can only process archive files in .zip format which kind of limits the
usability of the tool to only people with .zip packaged ROM.

# Open for Contributions
As a student i don't have enough time to make it completely compatible with other compression
methods, but I will definitely appreciate it if someone wil be able to help with that.
