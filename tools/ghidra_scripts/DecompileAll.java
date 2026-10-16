// Decompiles every function in the current program to <outdir>/<program>.c
// and writes a function index (<program>.functions.tsv).
// Usage (headless): -postScript DecompileAll.java <outdir>
//@category HXFix

import java.io.File;
import java.io.PrintWriter;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class DecompileAll extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		File outDir = new File(args.length > 0 ? args[0] : ".");
		outDir.mkdirs();
		String name = currentProgram.getName();

		DecompInterface decomp = new DecompInterface();
		decomp.setOptions(new DecompileOptions());
		decomp.openProgram(currentProgram);

		int count = 0, failed = 0;
		try (PrintWriter out = new PrintWriter(new File(outDir, name + ".c"), "UTF-8");
			 PrintWriter index = new PrintWriter(new File(outDir, name + ".functions.tsv"), "UTF-8")) {
			index.println("address\tsize\tname\tsignature");
			FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
			while (it.hasNext() && !monitor.isCancelled()) {
				Function f = it.next();
				index.println(f.getEntryPoint() + "\t" + f.getBody().getNumAddresses() + "\t"
					+ f.getName(true) + "\t" + f.getSignature().getPrototypeString());
				if (f.isThunk() || f.isExternal())
					continue;
				DecompileResults res = decomp.decompileFunction(f, 60, monitor);
				out.println("// ==== " + f.getName(true) + " @ " + f.getEntryPoint());
				if (res != null && res.decompileCompleted()) {
					out.println(res.getDecompiledFunction().getC());
				} else {
					out.println("// decompile failed: " + (res == null ? "null" : res.getErrorMessage()));
					failed++;
				}
				count++;
			}
		}
		decomp.dispose();
		println("DecompileAll: " + count + " functions, " + failed + " failed -> " + outDir);
	}
}
