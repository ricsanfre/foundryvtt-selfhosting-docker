FROM node:14-alpine

ARG VERSION=1.131.2

ENV ARCHIVE_SRC="5eTools.${VERSION}.zip"

ENV ARCHIVE_IMG="5eTools_img.${VERSION}.zip"

ARG URL="https://get.5e.tools/"

WORKDIR /app

# RUN mkdir img

RUN wget -O ${ARCHIVE_SRC} ${URL}/src/${ARCHIVE_SRC} && unzip -d . ${ARCHIVE_SRC} && rm ${ARCHIVE_SRC}

RUN wget -O ${ARCHIVE_IMG} ${URL}/img/${ARCHIVE_IMG} && unzip -d . ${ARCHIVE_IMG} && mv ./tmp/5et/img . && rm ${ARCHIVE_IMG}

RUN npm install

EXPOSE 5000

CMD ["npm","run","serve:dev"]


 
