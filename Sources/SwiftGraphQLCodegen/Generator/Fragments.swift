import Foundation
import GraphQLAST

/*
 We use fragments to support union and interface types.
 */

extension GraphQLCodegen {
    func generateFragmentSelection(
        _ name: String,
        for possibleTypes: [ObjectTypeRef],
        with objects: [ObjectType]
    ) -> [String] {
        /* Code parts */

        let parameters: [String] = possibleTypes.indexMap { index, element in
            let isLast = index == possibleTypes.count - 1
            // Last parameter to a function shouldn't have a comma.
            return "\(generateFnParameter(for: element))\(isLast ? "" : ",")"
        }
        let selection: [String] =
            ["/* Selection */",
             "self.select(["] + possibleTypes.map { generateFragmentSelection(for: $0) } +
            ["])"]
        let decoder: [String] =
            ["/* Decoder */",
             "switch self.response {",
             "case .decoding(let data):",
             "    switch data.__typename {"] + possibleTypes.flatMap { generateTypeDecoder(for: $0, with: objects) } +
            ["    }",
             "case .mocking:",
             "    return \(possibleTypes.first!.namedType.name.camelCase).mock()",
             "}"]

        /* Code */
        var code = [
            "extension Fields where TypeLock == \(name) {",
            "    func on<Type>(",
        ]
        code.append(contentsOf: parameters)
        code.append("    ) throws -> Type {")
        code.append(contentsOf: selection)
        code.append(contentsOf: decoder)
        code.append("    }")
        code.append("}")

        return code
    }

    private func generateFnParameter(for ref: ObjectTypeRef) -> String {
        "\(ref.namedType.name.camelCase): Selection<Type, Objects.\(ref.namedType.name.pascalCase)>"
    }

    private func generateTypeDecoder(
        for ref: ObjectTypeRef,
        with objects: [ObjectType]
    ) -> [String] {
        let name = ref.namedType.name
        let object = objects.first { $0.name == name }!

        /* Code */
        var code: [String] = [
            "case .\(name.camelCase):",
            "    let data = Objects.\(name.pascalCase)(",
        ]
        code.append(contentsOf: object.fields.indexMap { index, element in
            let name = element.name.camelCase
            let isLast = index == object.fields.count - 1
            // The last parameter shouldn't have a comma.
            return "\(name): data.\(name)\(isLast ? "" : ",")"
        })
        code.append("    )")
        code.append("    return try \(name.camelCase).decode(data: data)")

        return code
    }

    private func generateFragmentSelection(for ref: ObjectTypeRef) -> String {
        "GraphQLField.fragment(type: \"\(ref.namedType.name)\", selection: \(ref.namedType.name.camelCase).selection),"
    }
}
