# export-IPA
Update for XCode 8.3 (2017/4/10):
since specifying provision profile is not available from new version of XCode
(the tool will generate a plist file on ~/Downloads for ipa tool need)
some development/wildcard exporting might not work correctly...so sad
However, the tool still support generating enterprise / adhoc / some development ipa generations

if you are using older version(e.g. 8.1 or earlier) you can use commit 531caf393b0fb67815b73f4e36d811c412ac485a of this tool for better export support for development wildcard exports

==

Mac app for exporting ipa files from iOS Archives

Since XCode 6 requires setup in accounts for fetching code sign identity
using a command-line tool invoke can produce ipa files without the troublesome steps above
so I did this archive browser and provision browser for my self
(I don't want to add tens of customers account on my computer)

Thanks for Joshua's post saved lots of time reading mobileprovision files:
http://stackoverflow.com/a/19311285

please copy and place the server.plist settings file on the user directory of your computer, which will be reachable via NSHomeDirectory
