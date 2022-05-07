using Pkg
Pkg.add("JSON")
Pkg.add("UnicodePlots")

import JSON
import UnicodePlots
using UnicodePlots
using Dates
using DelimitedFiles
using Printf

function readRawJson(filename::String)
    lines = open(filename) do file
        readlines(file)
    end
    string("[", join(lines, ","), "]")
end

function getAlbumNumber(title::AbstractString)::Union{Int32, Nothing}
    @debug "Versuche Folgennummer zu extrahieren" title
    regex = r"(\d\d\d)[\/:]"
    rawMatch = match(regex, title)
    
    if isnothing(rawMatch)
        nothing
    else
        rawNumber = rawMatch[1]
        parse(Int32, rawNumber)
    end
end

function createTitleHistorgram(titles)
    numbers = something.(filter(!isnothing, map(a -> getAlbumNumber(a), titles)))
    histogram(numbers, nbins=60, vertical=true, title="Verteilung der Folgen")
end

function createTitleStairs(titles::Vector{String})
    # (title, title number)
    mapped =  map(title -> (title, getAlbumNumber(title)), titles)
    # (title, title number) - nur noch Folgen deren Nummer erkannt wurde
    filtered = filter(f -> !isnothing(f[2]), mapped)
    max = maximum(map(f -> f[2], filtered))
    min = 1
    range = [min:max;]
    binned = map(u -> (u, count(f -> u == f[2], filtered)), range)
    filter!(f -> f[1] < 215, binned)
    lineplot(map(f -> f[1], binned), map(f -> f[2], binned))
end

# Die Heatmap ist nur in farbig sinnvoll, daher wird sie nicht verwendet, weil die Ausgabe
# in die Textdatei natürlich nicht farbig ist.
function createTitleHeatmap(titles)
    # (title, title number)
    mapped =  map(title -> (title, getAlbumNumber(title)), titles)
    # (title, title number) - nur noch Folgen deren Nummer erkannt wurde
    filtered = filter(f -> !isnothing(f[2]), mapped)
    max = maximum(map(f -> f[2], filtered))
    rangeMax = Int32(ceil(max/15.0))
    rows = Int32(ceil(max / 15.0))
    matrix = zeros(Int32, rows, 15)
    range = [1:rangeMax*15;]
    binned = map(u -> (u, count(f -> u == f[2], filtered)), range)
    
    matrix = [ binned[Integer(floor(r*15+c))][2] for r=0:14, c=1:15 ]

    heatmap(matrix)
end

function distanceInHours(a::DateTime, b::DateTime)
    epochA = Dates.datetime2unix(a)
    epochB = Dates.datetime2unix(b)
    Δ = epochA - epochB
    Δ / 60 / 60
end

function createTilePlot(rawTimes)
    # Werte aus dem Logfile sehen folgendermaßen aus:
    #   2022-05-02T08:28:33.502Z
    format = dateformat"y-m-dTH:M:S"
    times = map(t -> DateTime(t[1:min(end-1, 19)], format), rawTimes)
    currentDate = now()
    lastHour = DateTime(Dates.year(currentDate), Dates.month(currentDate), Dates.day(currentDate), Dates.hour(currentDate), 0, 0)
    grouped = map(x -> (lastHour - Dates.Hour(x), lastHour - Dates.Hour(x - 1) - Dates.Millisecond(1)), reverse(Vector(0:80)))
    aggregated = map(((from, to), ) -> (from, count(time -> time >= from && time <= to, times)), grouped)
    lineplot(map(x -> distanceInHours(x[1], lastHour), aggregated), map(y -> y[2], aggregated), title = "Zugriffe pro Stunde der letzten 80 Stunden")
end

function readLines(filename::AbstractString)
    open(filename) do file
        readlines(file)
    end
end

function padLines!(a::Array{String}, target::Int)
    count = length(a)
    padLine = count > 0 ? repeat(" ", length(a[1])) : ""
    if(count > target)
        throw(ArgumentError("Der Array ist länger als die gewünschte Größe."))
    elseif count < target
        Δ = target - count
        for _ in 1:Δ
            push!(a, padLine)
        end
    end
end

function mergeLines!(a::Array{String}, b::Array{String})
    maxLines = max(length(a), (length(b)))
    padLines!(a, maxLines)
    padLines!(b, maxLines)

    zipped = zip(a, b)
    map(z -> z[1] * "  " * z[2], zipped)
end

if(isempty(ARGS))
    println("Das Programm erwartet als einzigen Parameter den Pfad zur Logdatei.")
    1
elseif(isfile(ARGS[1]))
    rawJson = readRawJson(ARGS[1])
    json = JSON.parse(rawJson)

    titles = map((e) -> e["message"]["albumName"], json)
    times = map((e) -> e["message"]["timestamp"], json)

    accessDistribution = createTilePlot(times)
    savefig(accessDistribution, "access.txt")
    accessLines = readLines("access.txt")

    titleDistribution = createTitleHistorgram(titles)
    savefig(titleDistribution, "titles.txt")
    titleLines = readLines("titles.txt")

    merged = mergeLines!(accessLines, titleLines)
    mergedFile = length(ARGS) > 1 ? ARGS[2] : "merged.txt"
    writedlm(mergedFile, merged)
    @printf("Graphen wurden in '%s' geschrieben.", mergedFile)
    0
else
    println("Der als Parameter übergebene Pfad existiert nicht.")
end