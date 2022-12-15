use libfalcon::{cli::run, error::Error, unit::gb, Runner};

#[tokio::main]
async fn main() -> Result<(), Error> {
    let mut r = Runner::new("om");

    // nodes (VMs)
    let om1 = r.node("rain-om1", "helios-1.3", 8, gb(12));
    let om2 = r.node("rain-om2", "helios-1.3", 8, gb(12));

    // Provide a link between hosts
    // This is interface `vioif0` inside the nodes
    r.link(om1, om2);

    // Link the two nodes to their host interface
    // This is a an etherstub in our case
    // It shows up inside the nodes as `vioif1`
    r.ext_link("om_stub0", om1);
    r.ext_link("om_stub0", om2);

    // Mount helper scripts inside the nodes
    r.mount("./cargo-bay", "/opt/cargo-bay", om1)?;
    r.mount("./cargo-bay", "/opt/cargo-bay", om2)?;

    run(&mut r).await?;

    // p9fs doesn't carry over file attributes
    // We also don't want to run in a nested bash shell as that affects how falcon tracks execution.
    let cmd = "chmod +x /opt/cargo-bay/firstboot.sh";
    let _ = r.exec(om1, cmd).await?;
    let _ = r.exec(om2, cmd).await?;

    // Setup a username, ipv4 address, etc.. based on firstboot.sh
    let cmd = "/opt/cargo-bay/firstboot.sh";
    let output = r.exec(om1, cmd).await?;
    println!("{}", output);
    let output = r.exec(om2, cmd).await?;
    println!("{}", output);

    Ok(())
}
