task "run" {
    backend = "local",
    description = "Build and rin",
    script = [=[
        crystal run src/gitlabff.cr
    ]=]
}

task "build:static" {
    backend = "local",
    description = "Build the static binary",
    script = [=[
        docker run --rm -it -v $(pwd):/workspace -w /workspace crystallang/crystal:latest-alpine crystal build src/gitlabff.cr --static --release -p -t -s -o bin/gitlabff
    ]=]
}