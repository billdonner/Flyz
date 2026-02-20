Deploy apps to Fly.io.

Run the deploy script from ~/Flyz for the specified app (or all apps).

Usage: /deploy [app-name|all]

Steps:
1. If no argument given, show available apps and ask which to deploy
2. Run `~/Flyz/scripts/deploy.sh <app>`
3. After deploy, run `fly status` to verify
4. Report results as a table: app name, status, URL
