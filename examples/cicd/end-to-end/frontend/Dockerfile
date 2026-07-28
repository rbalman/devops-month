# Frontend image — nginx serving the static UI + proxying /api to the backend.
FROM nginx:1.27-alpine

# Our server block replaces the default one.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# The static site.
COPY src/ /usr/share/nginx/html/

EXPOSE 80
