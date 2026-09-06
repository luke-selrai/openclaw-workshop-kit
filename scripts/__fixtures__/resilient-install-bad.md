# Resilient-install checker fixture - intentionally NON-resilient bootstrap

Feeds scripts/test-resilient-install.mjs. The block between the canonical
anchors below deliberately violates every resilient-install rule in
check-resilient-install.mjs, so the test can prove each detector fires. Do not
"fix" the prose - it is broken on purpose.

Since CORE-385 it doubles as the retired-door fixture: the Loup walkthrough it
carries is exactly the surface ADR-0003 removed, so the FORBIDDEN scan has
something real to catch. The legacy-home line below it is the counterpart - it
must NOT trip that scan, because MIGRATE still has to name the folders it
deletes.

I am setting up my Claude Code AI Business Assistant with Selr AI.

2. Get and run my install command.

   - Open the Loup dashboard and sign in at https://louphq.example/dashboard.
   - Ask me for my password and paste the token line back to you.
   - Run the command I paste and check the kit downloaded.
   - If it did not work, just tell me it failed and let me notify my facilitator
     or email Luke so someone else can sort the install out for me.
   - Delete ~/.loup/selr-ai/workshop-kit afterwards.

Talk to me like I am not technical. Plain English, one step at a time.
