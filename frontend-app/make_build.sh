#!/bin/bash

npm install --save-dev html-webpack-plugin
npm run build   # or yarn build depending on your project
#aws s3 sync dist/ s3://students-spa-djuni/ --delete

