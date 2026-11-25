import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.eclipse.xtext.validation.Issue;
import org.omg.sysml.interactive.SysMLInteractive;
import org.omg.sysml.interactive.SysMLInteractiveResult;

/**
 * Validates SysML v2 files with the OMG pilot implementation (SysMLInteractive).
 *
 * Usage:
 *   java -cp "<pilot>/jupyter-sysml-kernel-*-all.jar" tools/Validate.java \
 *        <sysml.library dir> [--strict] [--expect-fail] file1.sysml [file2.sysml ...]
 *
 * --strict       warnings count as failures
 * --expect-fail  the files are negative tests: each must produce at least one error
 *
 * Every file is processed in a fresh resource, so files do not see each other.
 * Exit code 0 when every file meets its expectation, 1 otherwise.
 */
public class Validate {

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: Validate <sysml.library> [--strict] [--expect-fail] files...");
            System.exit(2);
        }
        // The pilot's loader needs an absolute path with a trailing separator.
        String library = Path.of(args[0]).toAbsolutePath().normalize() + java.io.File.separator;
        boolean strict = false;
        boolean expectFail = false;
        List<String> files = new ArrayList<>();
        for (int i = 1; i < args.length; i++) {
            switch (args[i]) {
                case "--strict" -> strict = true;
                case "--expect-fail" -> expectFail = true;
                default -> files.add(args[i]);
            }
        }

        SysMLInteractive sysml = SysMLInteractive.getInstance();
        sysml.loadLibrary(library);

        int failures = 0;
        for (String file : files) {
            String text = Files.readString(Path.of(file));
            SysMLInteractiveResult result = sysml.process(text);
            List<Issue> errors = new ArrayList<>(result.getSyntaxErrors());
            errors.addAll(result.getSemanticErrors());
            List<Issue> warnings = result.getWarnings();
            boolean hasErrors = !errors.isEmpty() || result.getException() != null;

            boolean ok;
            String verdict;
            if (expectFail) {
                ok = hasErrors;
                verdict = ok ? "REJECTED (as expected)" : "ACCEPTED (expected rejection)";
            } else {
                ok = !hasErrors && !(strict && !warnings.isEmpty());
                verdict = ok ? "OK" : "FAIL";
            }
            System.out.printf("%-26s %s  [%d syntax, %d semantic, %d warnings]%n",
                    verdict, file, result.getSyntaxErrors().size(),
                    result.getSemanticErrors().size(), warnings.size());
            for (Issue issue : result.getIssues()) {
                System.out.printf("    %s line %s: %s%n", issue.getSeverity(),
                        issue.getLineNumber(), issue.getMessage());
            }
            if (result.getException() != null) {
                System.out.println("    exception: " + result.formatException());
            }
            if (!ok) failures++;
        }
        System.out.printf("%d file(s), %d not as expected%n", files.size(), failures);
        System.exit(failures == 0 ? 0 : 1);
    }
}
