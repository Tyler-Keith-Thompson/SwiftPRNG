// Reads a JSON array of cases on standard input and writes a JSON array of answers, one per case,
// in order (scripts/differential.py). The arguments, if any, name the sections to answer
// (`just diff --module X`); with none, every section is answered. A section not asked for is left
// out of the answer and not computed. Each section's case and answer live in a file of its own.

import Foundation

struct Case: Decodable {
    let generators: GeneratorsCase?
    let sampling: SamplingCase?
    let seedtrees: SeedTreesCase?
}

struct Answer: Encodable {
    var generators: GeneratorsAnswer?
    var sampling: SamplingAnswer?
    var seedtrees: SeedTreesAnswer?
}

let sections = Set(CommandLine.arguments.dropFirst())

func asked(_ section: String) -> Bool { sections.isEmpty || sections.contains(section) }

let cases = try JSONDecoder().decode([Case].self, from: FileHandle.standardInput.readDataToEndOfFile())
let answers = cases.map { item in
    var answer = Answer()
    if asked("generators"), let generators = item.generators {
        answer.generators = GeneratorsAnswer(generators)
    }
    if asked("sampling"), let sampling = item.sampling {
        answer.sampling = SamplingAnswer(sampling)
    }
    if asked("seedtrees"), let seedtrees = item.seedtrees {
        answer.seedtrees = SeedTreesAnswer(seedtrees)
    }
    return answer
}
FileHandle.standardOutput.write(try JSONEncoder().encode(answers))
