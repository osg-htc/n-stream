# pinned: change it in a PR, together with a new release (see RELEASING.md)
FROM almalinux/9-base:9.9-20261116

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
RUN yum -y update
RUN yum -y install python3-devel python3-pip
RUN pip install --no-cache-dir -r requirements.txt
ENV PYTHONPATH=/usr/src/app

COPY . .

CMD [ "bin/es_handler", "-l stdout"]
