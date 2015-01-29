# export-IPA
Mac app for exporting ipa files from iOS Archives

Since XCode 6 requires setup in accounts for fetching code sign identity
using a command-line tool invoke can produce ipa files without the troublesome steps above
so I did this archive browser and provision browser for my self
(I don't want to add tens of customers account on my computer)

Thanks for Joshua's post saved lots of time reading mobileprovision files:
http://stackoverflow.com/a/19311285

please copy and place the server.plist settings file on the user directory of your computer, which will be reachable via NSHomeDirectory
