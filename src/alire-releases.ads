with Ada.Tags;

with Alire.Actions;
with Alire.Conditional;
with Alire.Dependencies;
--  with Alire.Interfaces;
with Alire.Milestones;
with Alire.Origins;
with Alire.Projects;
with Alire.Properties;
with Alire.Properties.Labeled;
with Alire.Requisites;
with Alire.Utils;
with Alire.Versions;

with Semantic_Versioning;

private with Alire.OS_Lib;

package Alire.Releases with Preelaborate is
   
--     subtype Dependency_Vector is Dependencies.Vectors.Vector;

   type Release (<>) is 
     new Versions.Versioned
   with private;

   function "<" (L, R : Release) return Boolean;

   function New_Release (Project            : Alire.Project;
                         Version            : Semantic_Versioning.Version;
                         Origin             : Origins.Origin;
                         Notes              : Description_String;
                         Dependencies       : Conditional.Dependencies;
                         Properties         : Conditional.Properties;
                         Private_Properties : Conditional.Properties;
                         Available          : Alire.Requisites.Tree) return Release;
   
   function New_Working_Release 
     (Project      : Alire.Project;
      Origin       : Origins.Origin := Origins.New_Filesystem (".");
      Dependencies : Conditional.Dependencies := Conditional.For_Dependencies.Empty;
      Properties   : Conditional.Properties   := Conditional.For_Properties.Empty)
      return         Release;
   --  For working project releases that may have incomplete information

   function Extending (Base               : Release;
                       Dependencies       : Conditional.Dependencies := Conditional.For_Dependencies.Empty;
                       Properties         : Conditional.Properties   := Conditional.For_Properties.Empty;
                       Private_Properties : Conditional.Properties   := Conditional.For_Properties.Empty;
                       Available          : Alire.Requisites.Tree    := Requisites.Trees.Empty_Tree)                        
                       return Release;
   --  Takes a release and merges given fields
             
   function Renaming (Base     : Release;
                      Provides : Alire.Project) return Release;
   
   function Renaming (Base     : Release;
                      Provides : Projects.Named'Class) return Release;
   --  Fills-in the "provides" field
   --  During resolution, a project that has a renaming will act as the
   --    "Provides" project, so both projects cannot be selected simultaneously.
   
   function Replacing (Base               : Release;
                       Project            : Alire.Project      := "";
                       Notes              : Description_String := "") return Release;      
   --  Takes a release and replaces the given fields
   
   function Replacing (Base         : Release;
                       Dependencies : Conditional.Dependencies) return Release;
   
   function Replacing (Base   : Release;
                       Origin : Origins.Origin) return Release;  
   
   function Retagging (Base    : Release;
                       Version : Semantic_Versioning.Version) return Release;
   --  Keep all data but version
   
   function Upgrading (Base    : Release;
                       Version : Semantic_Versioning.Version;
                       Origin  : Origins.Origin) return Release;
   --  Takes a release and replaces version and origin   

   function Whenever (R : Release; P : Properties.Vector) return Release;
   --  Materialize conditions in a Release once the whatever properties are known
   --  At present dependencies and properties
   
   overriding function Project (R : Release) return Alire.Project;   
   
   function Project_Str (R : Release) return String is (+R.Project);
   
   function Project_Base (R : Release) return String;
   --  Project up to first dot, if any; which is needed for extension projects in templates and so on
   
   function Provides (R : Release) return Alire.Project;
   --  The actual project name to be used during dependency resolution 
   --  (But nowhere else)
   
   function Is_Extension (R : Release) return Boolean;
   
   function Notes   (R : Release) return Description_String; -- Specific to release
   function Version (R : Release) return Semantic_Versioning.Version;
   
   function Depends (R : Release) return Conditional.Dependencies;
   function Dependencies (R : Release) return Conditional.Dependencies
     renames Depends;
   
   function Depends (R : Release;
                     P : Properties.Vector)
                     return Conditional.Dependencies;
   --  Not really conditional anymore, but still a potential tree
   function Dependencies (R : Release;
                          P : Properties.Vector)
                          return Conditional.Dependencies renames Depends;
   
   function Origin  (R : Release) return Origins.Origin;
   function Available (R : Release) return Requisites.Tree;

   function Default_Executable (R : Release) return String;
   --  We encapsulate here the fixing of platform extension

   function Executables (R : Release; 
                         P : Properties.Vector) 
                         return Utils.String_Vector;
   -- Only explicity declared ones
   -- Under some conditions (usually current platform)

   function Project_Paths (R         : Release;
                           P         : Properties.Vector) return Utils.String_Set;
   --  Deduced from Project_Files
   
   function Project_Files (R         : Release;
                           P         : Properties.Vector;
                           With_Path : Boolean)
                           return Utils.String_Vector;
   --  with relative path on demand

   function Unique_Folder (R : Release) return Folder_String;

   --  NOTE: property retrieval functions do not distinguish between public/private, since that's 
   --  merely informative for the users

   function On_Platform_Actions (R : Release; P : Properties.Vector) return Properties.Vector;
   --  Get only Action properties for the platform
   
   function On_Platform_Properties (R             : Release; 
                                    P             : Properties.Vector;
                                    Descendant_Of : Ada.Tags.Tag := Ada.Tags.No_Tag) 
                                    return Properties.Vector;
   --  Return properties that apply to R under platform properties P
   
   function Labeled_Properties (R     : Release; 
                                P     : Properties.Vector; 
                                Label : Properties.Labeled.Labels) 
                                return Utils.String_Vector;
   --  Get all values for a given property for a given platform properties
   
   function Milestone (R : Release) return Milestones.Milestone;

   procedure Print (R : Release; Private_Too : Boolean := False);
   -- Dump info to console   

--     overriding function To_Code (R : Release) return Utils.String_Vector;
   
   --  Search helpers

   function Property_Contains (R : Release; Str : String) return Boolean;
   --  True if some property contains the given string
   
   function Satisfies (R : Release; Dep : Alire.Dependencies.Dependency) return Boolean;
   --  Ascertain if this release is a valid candidate for Dep
   
private
   
   use Semantic_Versioning;
   
   function Materialize is new Conditional.For_Properties.Materialize
     (Properties.Vector, Properties.Append);
   
   function Enumerate is new Conditional.For_Properties.Enumerate
     (Properties.Vector, Properties.Append);
   
   function All_Properties (R : Release;
                            P : Properties.Vector) return Properties.vector;  
   --  Properties that R has un der platform properties P

   use Alire.Properties;
   function Comment  is new Alire.Properties.Labeled.Cond_New_Label (Alire.Properties.Labeled.Comment);
   function Describe is new Alire.Properties.Labeled.Cond_New_Label (Alire.Properties.Labeled.Description);

   type Release (Prj_Len, 
                 Notes_Len : Natural) is 
     new Versions.Versioned
   with record 
      Project      : Alire.Project (1 .. Prj_Len);
      Alias        : Ustring; -- I finally gave up on constraints
      Version      : Semantic_Versioning.Version;
      Origin       : Origins.Origin;
      Notes        : Description_String (1 .. Notes_Len);      
      Dependencies : Conditional.Dependencies;
      Properties   : Conditional.Properties;
      Priv_Props   : Conditional.Properties;
      Available    : Requisites.Tree;
   end record;

   use all type Conditional.Properties;

   function "<" (L, R : Release) return Boolean is
     (L.Project < R.Project or else
        
      (L.Project = R.Project and then
       L.Version < R.Version) or else
      
      (L.Project = R.Project and then
       L.Version = R.Version and then
       Build (L.Version) < Build (R.Version)));
   
   function Is_Extension (R : Release) return Boolean is
      (R.Project_Base'Length < R.Project'Length);
   
   overriding function Project (R : Release) return Alire.Project is (R.Project);  
   
   function Project_Base (R : Release) return String is
     (Utils.Head (+R.Project, Extension_Separator));
   
   function Provides (R : Release) return Alire.Project is 
     ((if Ustrings.Length (R.Alias) = 0
       then R.Project
       else +(+R.Alias)));
   
   function Notes (R : Release) return Description_String is (R.Notes);
   
   function Depends (R : Release) return Conditional.Dependencies is (R.Dependencies); 
   
   function Depends (R : Release;
                     P : Properties.Vector)
                     return Conditional.Dependencies is 
     (R.Dependencies.Evaluate (P));
   
   function Origin  (R : Release) return Origins.Origin is (R.Origin);
   function Available (R : Release) return Requisites.Tree is (R.Available);

   function Milestone (R : Release) return Milestones.Milestone is
      (Milestones.New_Milestone (R.Project, R.Version));

   function Default_Executable (R : Release) return String is
      (Utils.Replace (+R.Project, ":", "_") & OS_Lib.Exe_Suffix);

   use all type Origins.Kinds;
   function Unique_Folder (R : Release) return Folder_String is
     (Utils.Head (+R.Project, Extension_Separator) & "_" &
      Image (R.Version) & "_" &
      (case R.Origin.Kind is
          when Filesystem => "filesystem",
          when Native     => "native",
          when Git | Hg   => (if R.Origin.Commit'Length <= 8 
                              then R.Origin.Commit
                              else R.Origin.Commit (R.Origin.Commit'First .. R.Origin.Commit'First + 7))));
   
   function On_Platform_Actions (R : Release; P : Properties.Vector) return Properties.Vector is
     (R.On_Platform_Properties (P, Actions.Action'Tag));
   
   function Satisfies (R : Release; Dep : Alire.Dependencies.Dependency) return Boolean is
     (R.Project = Dep.Project and then
      Satisfies (R.Version, Dep.Versions));

end Alire.Releases;
