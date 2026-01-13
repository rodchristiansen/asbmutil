import ArgumentParser

@main
struct ASBMUtil: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "asbmutil",
        abstract: "Apple School & Business Manager CLI",
        subcommands: [
            Config.self,
            ListDevices.self, 
            Assign.self, 
            Unassign.self, 
            BatchStatus.self, 
            ListMdmServers.self, 
            GetAssignedMdm.self,
            GetAppleCare.self
        ]
    )
}
