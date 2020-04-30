#!/bin/bash


echo "export DB_HOST='mongodb://${db_priv_ip}:27017/posts'" >> /home/ubuntu/.bashrc
echo "export DB_HOST='mongodb://${db_priv_ip}:27017/posts'" >> /home/ubuntu/.profile
source /home/ubuntu/.bashrc
source /home/ubuntu/.profile

cd /home/ubuntu/app
sudo npm install
sudo chown -R 1000:1000 "/home/ubuntu/.npm"
export DB_HOST=mongodb://${db_priv_ip}:27017/posts
nodejs seeds/seed.js
npm start
