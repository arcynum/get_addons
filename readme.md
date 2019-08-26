Nifty powershell script to automatically update your wow addons.
It has been designed around classic, as that is what I will be playing - however it should work for retail as well.

I built this to replace the ad-filled crap produced by twitch/curse/etc for automatically updating your addons.

How it works:
1. Add in your wow folder in the config.json file
2. Add the list of addons you want to be installed in the config.json file
3. Run the powershell script


Features:
1. Downloads addons from existing addons hosts, including github, legacy-wow, curseforge
2. Supports downloading a zip file directly, or navigating to the latest release tag in github
3. Automatically backs up existing addons if they are being updated, so you can easily roll back
4. Checks the addon versions by hashing the TOC file - any difference and the addon will get replaced
