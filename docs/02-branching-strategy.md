# Branching strategy

## Chosen strategy
I det här projektet använder jag Trunk-based development (korta grenar mot en gemensam main-gren). Eftersom jag arbetar ensam i repot och pipelinen i kommande moduler förväntas köra ofta mot huvudgrenen, är det viktigt med små och frekventa ändringar (korta ledtider). Långlivade funktionsgrenar skulle bara skjuta upp integrationen och öka risken för merge-konflikter.

## Branch protection
I ett team-scenario skulle jag aktivera grenskydd (Branch protection rules) för `main` och slå på regeln "Require a pull request before merging". Det gör Pull Requesten till en tvingande kvalitetsgrind så att ingen kan pusha kod direkt till produktion utan granskning. Tillsammans med filen `CODEOWNERS` säkerställer detta att rätt personer (ofta kodens ägare) granskar ändringen innan sammanslagning. I det här soloprojektet hålls godkännandekravet avstängt så att jag inte låser ut mig själv från sammanslagningar.

## Tagging and versioning
v0.1.0 is the first tagged version. The repo has a branching strategy, a pull request template and a CODEOWNERS file, but no application yet. The 0 in front means everything can still change. 

The next version number follows from the commit messages based on Conventional Commits and Semantic Versioning (MAJOR.MINOR.PATCH): 
* a `fix:` gives v0.1.1 (PATCH)
* a `feat:` gives v0.2.0 (MINOR)
* a `feat!:` (breaking change) gives v1.0.0 (MAJOR)
* a `docs:` change does not change the version at all.