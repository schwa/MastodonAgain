import Foundation

public struct Expression {
    public enum Atom {
        case literal(String)
        case lookup(name: String)
    }

    var atoms: [Atom] = []
}

extension Expression: CustomStringConvertible {
    public var description: String {
        return atoms.reduce("") { partialResult, atom in
            switch atom {
            case .literal(let literal):
                return partialResult + literal
            case .lookup(name: let name):
                return partialResult + "\\(lookup: \"\(name)\")"
            }
        }
    }
}

public extension Expression {
    init(_ value: String) {
        atoms = [.literal(value)]
    }
}

extension Expression: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        atoms = [.literal(value)]
    }
}

extension Expression: ExpressibleByStringInterpolation {
    public init(stringInterpolation: Interpolation) {
        atoms = stringInterpolation.atoms
    }

    public struct Interpolation: StringInterpolationProtocol {
        var atoms: [Atom] = []

        public init(literalCapacity: Int, interpolationCount: Int) {
        }

        public mutating func appendLiteral(_ literal: String) {
            guard !literal.isEmpty else {
                return
            }
            atoms.append(.literal(literal))
        }

        public mutating func appendInterpolation(lookup name: String) {
            atoms.append(.lookup(name: name))
        }
    }
}

public extension Expression {

    var string: String {
        get throws {
            return try resolve([:])
        }
    }

    func canResolve(_ variables: [String: String]) -> Bool {
        let unresolvable = atoms.contains { atom in
            guard case let .lookup(name) = atom else {
                return false
            }
            return variables[name] == nil
        }
        return !unresolvable
    }

    func resolve(_ variables: [String: String]) throws -> String {
        return try atoms.reduce("") { partialResult, atom in
            switch atom {
            case .literal(let literal):
                return partialResult + literal
            case .lookup(name: let name):
                guard let value = variables[name] else {
                    throw BlueprintError.failedToResolveName(name)
                }
                return partialResult + value
            }
        }
    }
}

// MARK: -

internal extension Dictionary where Key == String, Value == Request.Parameter {
    func resolve(_ variables: [String: String]) throws -> Self {
        return try Dictionary(uniqueKeysWithValues: compactMap { key, value in
            switch value {
            case .required(let expression):
                let expression = try expression.resolve(variables)
                return (key, .required(Expression(expression)))
            case .optional(let expression):
                if expression.canResolve(variables) == false {
                    return nil
                }
                else {
                    let expression = try expression.resolve(variables)
                    return (key, .optional(Expression(expression)))
                }
            }
        })
    }
}
