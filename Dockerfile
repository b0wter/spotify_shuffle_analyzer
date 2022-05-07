FROM julia:1.7-bullseye
WORKDIR /data
WORKDIR /app
COPY main.jl .
RUN julia -e 'using Pkg; Pkg.add("JSON")'
RUN julia -e 'using Pkg; Pkg.add("UnicodePlots")'
ENTRYPOINT ["julia", "main.jl"]
