# Validates .docx files with Microsoft's Open XML SDK (see Program.cs).
#
#   docker build --tag caracal-ooxml-validator .github/ooxml-validator
#   docker run --rm --volume "$PWD/tmp/ooxml:/docs:ro" caracal-ooxml-validator /docs
#
# `rake ooxml` does both for every document the specs render.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY OoxmlValidator.csproj .
RUN dotnet restore
COPY Program.cs .
RUN dotnet publish --no-restore --configuration Release --output /app

FROM mcr.microsoft.com/dotnet/runtime:10.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "OoxmlValidator.dll"]
