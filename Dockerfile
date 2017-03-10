FROM ubuntu:trusty
ENV VERSION_EBTREE=v6.0.socio6 \
    VERSION_DMD1=v1.078.0 \
    VERSION_TANGORT=v1.6.0 \
    VERSION_DMD=2.071.2-0 \
    VERSION_DMD_TRANSITIONAL=v2.071.2 \
    VERSION_D1TO2FIX=v0.9.0
LABEL \
    maintainer="Leandro Lucarella <leandro.lucarella@sociomantic.com>" \
    description="General purpose, platform-dependant, high-performance library for D (CI image)" \
    com.sociomantic.version.ebtree=$VERSION_EBTREE \
    com.sociomantic.version.dmd1=$VERSION_DMD1 \
    com.sociomantic.version.tangort=$VERSION_TANGORT \
    com.sociomantic.version.dmd=$VERSION_DMD \
    com.sociomantic.version.dmd-transitional=$VERSION_DMD_TRANSITIONAL \
    com.sociomantic.version.d1to2fix=$VERSION_D1TO2FIX
COPY docker/ ./
RUN ./base.sh
RUN ./ebtree.sh $VERSION_EBTREE
RUN ./dmd1.sh $VERSION_DMD1
RUN ./tangort.sh $VERSION_TANGORT
RUN ./dmd.sh $VERSION_DMD
RUN ./dmd-transitional.sh $VERSION_DMD_TRANSITIONAL
RUN ./d1to2fix.sh $VERSION_D1TO2FIX
RUN ./ocean.sh
RUN rm *.sh
