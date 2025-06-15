import ArgumentParser

@main
struct ASBMUtil: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "asbmutil",
        abstract: "Apple School & Business Manager CLI",
        subcommands: [ListDevices.self, Assign.self, Unassign.self, BatchStatus.self, Config.self, ListMdmServers.self, GetAssignedMdm.self]
    )
}
