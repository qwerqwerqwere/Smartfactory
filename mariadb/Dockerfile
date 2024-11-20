FROM mariadb:10.6.19

LABEL maintainer="team@appwrite.io"

# Add appwrite schema and tables
ADD ./default.sql /docker-entrypoint-initdb.d/default.sql

RUN chown -R mysql:mysql /docker-entrypoint-initdb.d/
