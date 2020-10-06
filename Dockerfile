FROM blcdsdockerregistry/docker-bb-base:latest

RUN installGithub.r Wedge-lab/battenberg@9537a58369

CMD ["/bin/bash"]
