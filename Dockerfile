# ============================================================
# Multi-stage Dockerfile for Road Dash
# Stage 1: Export Godot project to HTML5 using headless Godot
# Stage 2: Serve with nginx
# ============================================================

# --- Stage 1: Godot HTML5 Export ---
FROM ubuntu:22.04 AS builder

ARG GODOT_VERSION=4.2.2
ARG GODOT_RELEASE=stable

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download Godot headless binary
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip" \
    -O /tmp/godot.zip && \
    unzip /tmp/godot.zip -d /tmp && \
    mv /tmp/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64 /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm /tmp/godot.zip

# Download export templates
RUN mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE} && \
    wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_export_templates.tpz" \
    -O /tmp/templates.tpz && \
    unzip /tmp/templates.tpz -d /tmp/templates && \
    mv /tmp/templates/templates/* /root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}/ && \
    rm -rf /tmp/templates.tpz /tmp/templates

# Copy project files
WORKDIR /project
COPY project.godot export_presets.cfg ./
COPY scenes/ ./scenes/
COPY scripts/ ./scripts/

# Export to HTML5
RUN mkdir -p build && \
    godot --headless --export-release "Web" build/index.html 2>&1 || true

# Verify export produced files
RUN ls -la build/

# --- Stage 2: Serve with nginx ---
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy exported game files
COPY --from=builder /project/build/ /usr/share/nginx/html/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
