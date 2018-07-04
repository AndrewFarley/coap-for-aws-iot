FROM node:8
EXPOSE 5683:5683/udp

RUN npm i npm@latest -g

COPY package*.json ./
RUN npm install

# Bugfix from https://github.com/mafintosh/sqs/pull/36
ADD https://raw.githubusercontent.com/trenskow/sqs/master/index.js /node_modules/sqs/index.js

COPY server.js .

CMD [ "npm", "start" ]

