#! /bin/bash

# update repo
git stash
git pull
npm install


# build web app
cd web
rm -r dist/
npm install
npm run build

# start server
cd ..
npm run start