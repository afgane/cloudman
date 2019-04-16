FROM ubuntu:18.04 as stage1

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED 1

ENV KUBE_LATEST_VERSION=v1.14.1
ENV HELM_VERSION=v2.9.1
ENV HELM_FILENAME=helm-${HELM_VERSION}-linux-amd64.tar.gz

RUN set -xe; \
    apt-get -qq update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        git-core \
        make \
        software-properties-common \
        gcc \
        python3-dev \
        libffi-dev \
        libpq-dev \
        python-psycopg2 \
        python3-pip \
        python3-setuptools \
        curl \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && curl -L https://storage.googleapis.com/kubernetes-helm/${HELM_FILENAME} | tar xz && mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64 \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir -p /app \
    && pip3 install virtualenv \
    && virtualenv -p python3 --prompt "(cloudman)" /app/venv

# Set working directory to /app/
WORKDIR /app/

# Add files to /app/
ADD . /app

# Install requirements. Move this above ADD as 'pip install cloudman-server'
# asap so caching works
RUN /app/venv/bin/pip3 install -U pip && /app/venv/bin/pip3 install --no-cache-dir -r requirements.txt

RUN cd cloudman && /app/venv/bin/python manage.py collectstatic --no-input


# Stage-2
FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED 1

# Env vars required for correct cloudman bootup
# ENV RANCHER_URL
# ENV RANCHER_TOKEN
# ENV RANCHER_CLUSTER_ID
# ENV RANCHER_PROJECT_ID

# Create cloudman user environment
RUN useradd -ms /bin/bash cloudman \
    && mkdir -p /app \
    && chown cloudman:cloudman /app -R \
    && apt-get -qq update && apt-get install -y --no-install-recommends \
        git-core \
        python-psycopg2 \
        python3-pip \
        python3-setuptools \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

WORKDIR /app/cloudman/

# Copy cloudman files to final image
COPY --chown=cloudman:cloudman --from=stage1 /app /app
COPY --chown=cloudman:cloudman --from=stage1 /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --chown=cloudman:cloudman --from=stage1 /usr/local/bin/helm /usr/local/bin/helm

RUN chmod a+x /app/venv/bin/*
RUN chmod a+x /usr/local/bin/kubectl
RUN chmod a+x /usr/local/bin/helm

# Switch to new, lower-privilege user
USER cloudman

# gunicorn will listen on this port
EXPOSE 8000

CMD /app/venv/bin/gunicorn -k gevent -b :8000 --access-logfile - --error-logfile - --log-level debug cloudman.wsgi
#CMD /app/venv/bin/python /app/cloudman/manage.py runserver

