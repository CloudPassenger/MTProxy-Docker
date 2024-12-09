
# Stage 1: Build MTProxy core
FROM gcc:14-bookworm AS core-builder
WORKDIR /build
COPY core/ .
RUN make

# Stage 2: Build MTProxy manager
FROM rust:1-bookworm AS manager-builder
WORKDIR /build
COPY manager/ .
RUN cargo build --release

# Stage 3: Collect required shared libraries
FROM debian:bookworm-slim AS library-collector
COPY --from=core-builder /build/objs/bin/mtproto-proxy /mtproto-proxy
RUN mkdir -p /lib_deps && \
    ldd /mtproto-proxy | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /lib_deps && \
    cp $(ldconfig -p | grep -E 'ld-linux.*\.so\.2' | awk 'NR==1{print $NF}') /lib_deps/

# Stage 4: Final minimal image
FROM gcr.io/distroless/cc-debian12

# Copy necessary libraries
COPY --from=library-collector /lib_deps/* /lib/
# Copy the built executables from previous stages
COPY --from=core-builder /build/objs/bin/mtproto-proxy /mtproto-proxy
COPY --from=manager-builder /build/target/release/mtproxy-manager /mtproxy-manager

# Create and declare the configuration volume
VOLUME ["/conf"]

# Set the entrypoint
ENTRYPOINT ["/mtproxy-manager"]
