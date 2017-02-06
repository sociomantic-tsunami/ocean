FROM ubuntu:trusty
COPY docker/ ./
RUN ./base.sh
RUN ./ebtree.sh v6.0.socio6
RUN ./dmd1.sh v1.078.0
RUN ./tangort.sh v1.6.0
RUN ./dmd.sh 2.070.2-0
RUN ./dmd-transitional.sh v2.070.2
RUN ./d1to2fix.sh v0.9.0
RUN ./ocean.sh
RUN rm *.sh
