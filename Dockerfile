# ==================================================
# Multi-stage Dockerfile para VianaHub.VianaID.Api
# Otimizado para produção com ASP.NET Core 8.0
# ==================================================

# --------------------------------------------------
# Stage 1: Base runtime image
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Configurações de segurança e performance
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser && \
    apk add --no-cache \
        icu-libs \
        tzdata && \
    ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    TZ=America/Sao_Paulo

# --------------------------------------------------
# Stage 2: Build
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copia arquivos de projeto para restaurar dependências (cache layer)
COPY ["src/VianaHub.VianaID.Api/VianaHub.VianaID.Api.csproj", "src/VianaHub.VianaID.Api/"]
COPY ["src/VianaHub.VianaID.Application/VianaHub.VianaID.Application.csproj", "src/VianaHub.VianaID.Application/"]
COPY ["src/VianaHub.VianaID.Domain/VianaHub.VianaID.Domain.csproj", "src/VianaHub.VianaID.Domain/"]
COPY ["src/VianaHub.VianaID.Infra.Data/VianaHub.VianaID.Infra.Data.csproj", "src/VianaHub.VianaID.Infra.Data/"]
COPY ["src/VianaHub.VianaID.Infra.IoC/VianaHub.VianaID.Infra.IoC.csproj", "src/VianaHub.VianaID.Infra.IoC/"]
COPY ["src/VianaHub.VianaID.Infra.Background/VianaHub.VianaID.Infra.Background.csproj", "src/VianaHub.VianaID.Infra.Background/"]
COPY ["src/VianaHub.VianaID.Infra.Integration/VianaHub.VianaID.Infra.Integration.csproj", "src/VianaHub.VianaID.Infra.Integration/"]

# Restaura dependências
RUN dotnet restore "src/VianaHub.VianaID.Api/VianaHub.VianaID.Api.csproj"

# Copia o restante do código fonte
COPY . .

# Build da aplicação
WORKDIR "/src/src/VianaHub.VianaID.Api"
RUN dotnet build "VianaHub.VianaID.Api.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/build \
    --no-restore

# --------------------------------------------------
# Stage 3: Publish
# --------------------------------------------------
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "VianaHub.VianaID.Api.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/publish \
    --no-restore \
    --no-build \
    /p:UseAppHost=false

# --------------------------------------------------
# Stage 4: Final - Runtime
# --------------------------------------------------
FROM base AS final
WORKDIR /app

# Copia os artefatos publicados
COPY --from=publish --chown=appuser:appuser /app/publish .

# Cria diretórios necessários
RUN mkdir -p /app/logs && \
    chown -R appuser:appuser /app/logs

# Usa usuário não-root por segurança
USER appuser

# Health check nativo do Docker
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health/live || exit 1

# Labels para metadados
LABEL maintainer="VianaHub DevOps Team <devops@vianahub.com>" \
      version="1.0.0" \
      description="VianaHub Identity and Access Management API" \
      org.opencontainers.image.source="https://dev.azure.com/vianahub/VianaHub/_git/VianaHub.VianaID"

ENTRYPOINT ["dotnet", "VianaHub.VianaID.Api.dll"]
