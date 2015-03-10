unit ce_projinspect;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, FileUtil, TreeFilterEdit, Forms, Controls, Graphics, ActnList,
  Dialogs, ExtCtrls, ComCtrls, Menus, Buttons, lcltype, ce_project, ce_interfaces,
  ce_common, ce_widget, ce_observer;

type
  TCEProjectInspectWidget = class(TCEWidget, ICEProjectObserver)
    btnRemFold: TSpeedButton;
    imgList: TImageList;
    Panel1: TPanel;
    btnAddFile: TSpeedButton;
    btnProjOpts: TSpeedButton;
    btnAddFold: TSpeedButton;
    btnRemFile: TSpeedButton;
    Tree: TTreeView;
    TreeFilterEdit1: TTreeFilterEdit;
    procedure btnAddFileClick(Sender: TObject);
    procedure btnAddFoldClick(Sender: TObject);
    procedure btnRemFileClick(Sender: TObject);
    procedure btnRemFoldClick(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeSelectionChanged(Sender: TObject);
  protected
    procedure updateImperative; override;
    procedure updateDelayed; override;
    procedure SetVisible(Value: boolean); override;
  private
    fActOpenFile: TAction;
    fActSelConf: TAction;
    fProject: TCEProject;
    fFileNode, fConfNode: TTreeNode;
    fImpsNode, fInclNode: TTreeNode;
    fXtraNode: TTreeNode;
    procedure actUpdate(Sender: TObject);
    procedure TreeDblClick(Sender: TObject);
    procedure actOpenFileExecute(Sender: TObject);
    //
    procedure projNew(aProject: TCEProject);
    procedure projClosing(aProject: TCEProject);
    procedure projFocused(aProject: TCEProject);
    procedure projChanged(aProject: TCEProject);
    procedure projCompiling(aProject: TCEProject);
  protected
    function contextName: string; override;
    function contextActionCount: integer; override;
    function contextAction(index: integer): TAction; override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

uses
  ce_symstring;

{$REGION Standard Comp/Obj------------------------------------------------------}
constructor TCEProjectInspectWidget.Create(aOwner: TComponent);
var
  png: TPortableNetworkGraphic;
begin
  fActOpenFile := TAction.Create(self);
  fActOpenFile.Caption := 'Open file in editor';
  fActOpenFile.OnExecute := @actOpenFileExecute;
  fActSelConf := TAction.Create(self);
  fActSelConf.Caption := 'Select configuration';
  fActSelConf.OnExecute := @actOpenFileExecute;
  fActSelConf.OnUpdate := @actUpdate;
  //
  inherited;
  //
  png := TPortableNetworkGraphic.Create;
  try
    png.LoadFromLazarusResource('document_add');
    btnAddFile.Glyph.Assign(png);
    png.LoadFromLazarusResource('document_delete');
    btnRemFile.Glyph.Assign(png);
    png.LoadFromLazarusResource('folder_add');
    btnAddFold.Glyph.Assign(png);
    png.LoadFromLazarusResource('folder_delete');
    btnRemFold.Glyph.Assign(png);
    png.LoadFromLazarusResource('wrench_orange');
    btnProjOpts.Glyph.Assign(png);
  finally
    png.Free;
  end;
  //
  Tree.OnDblClick := @TreeDblClick;
  fFileNode := Tree.Items[0];
  fConfNode := Tree.Items[1];
  fImpsNode := Tree.Items[2];
  fInclNode := Tree.Items[3];
  fXtraNode := Tree.Items[4];
  //
  Tree.PopupMenu := contextMenu;
  //
  EntitiesConnector.addObserver(self);
end;

destructor TCEProjectInspectWidget.Destroy;
begin
  EntitiesConnector.removeObserver(self);
  inherited;
end;

procedure TCEProjectInspectWidget.SetVisible(Value: boolean);
begin
  inherited;
  if Value then
    updateImperative;
end;

{$ENDREGION}

{$REGION ICEContextualActions---------------------------------------------------}
function TCEProjectInspectWidget.contextName: string;
begin
  exit('Inspector');
end;

function TCEProjectInspectWidget.contextActionCount: integer;
begin
  exit(2);
end;

function TCEProjectInspectWidget.contextAction(index: integer): TAction;
begin
  case index of
    0: exit(fActOpenFile);
    1: exit(fActSelConf);
    else
      exit(nil);
  end;
end;

procedure TCEProjectInspectWidget.actOpenFileExecute(Sender: TObject);
begin
  TreeDblClick(Sender);
end;

{$ENDREGION}

{$REGION ICEProjectMonitor -----------------------------------------------------}
procedure TCEProjectInspectWidget.projNew(aProject: TCEProject);
begin
  fProject := aProject;
  if Visible then
    updateImperative;
end;

procedure TCEProjectInspectWidget.projClosing(aProject: TCEProject);
begin
  if fProject <> aProject then
    exit;
  fProject := nil;
  updateImperative;
end;

procedure TCEProjectInspectWidget.projFocused(aProject: TCEProject);
begin
  fProject := aProject;
  if Visible then
    beginDelayedUpdate;
end;

procedure TCEProjectInspectWidget.projChanged(aProject: TCEProject);
begin
  if fProject <> aProject then
    exit;
  if Visible then
    beginDelayedUpdate;
end;

procedure TCEProjectInspectWidget.projCompiling(aProject: TCEProject);
begin
end;

{$ENDREGION}

{$REGION Inspector things -------------------------------------------------------}
procedure TCEProjectInspectWidget.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
    TreeDblClick(nil);
end;

procedure TCEProjectInspectWidget.TreeSelectionChanged(Sender: TObject);
begin
  actUpdate(Sender);
end;

procedure TCEProjectInspectWidget.TreeDblClick(Sender: TObject);
var
  fname: string;
  i: NativeInt;
begin
  if fProject = nil then
    exit;
  if Tree.Selected = nil then
    exit;
  //
  if (Tree.Selected.Parent = fFileNode) or (Tree.Selected.Parent = fXtraNode) then
  begin
    fname := Tree.Selected.Text;
    i := fProject.Sources.IndexOf(fname);
    if i > -1 then
      fname := fProject.getAbsoluteSourceName(i);
    if dExtList.IndexOf(ExtractFileExt(fname)) <> -1 then
      if fileExists(fname) then
        getMultiDocHandler.openDocument(fname);
  end
  else if Tree.Selected.Parent = fConfNode then
  begin
    i := Tree.Selected.Index;
    fProject.ConfigurationIndex := i;
    beginDelayedUpdate;
  end;
end;

procedure TCEProjectInspectWidget.actUpdate(Sender: TObject);
begin
  fActSelConf.Enabled := False;
  fActOpenFile.Enabled := False;
  if Tree.Selected = nil then
    exit;
  fActSelConf.Enabled := Tree.Selected.Parent = fConfNode;
  fActOpenFile.Enabled := Tree.Selected.Parent = fFileNode;
end;

procedure TCEProjectInspectWidget.btnAddFileClick(Sender: TObject);
begin
  if fProject = nil then
    exit;
  //
  with TOpenDialog.Create(nil) do
    try
      filter := DdiagFilter;
      if Execute then
      begin
        fProject.beginUpdate;
        fProject.addSource(filename);
        fProject.endUpdate;
      end;
    finally
      Free;
    end;
end;

procedure TCEProjectInspectWidget.btnAddFoldClick(Sender: TObject);
var
  dir, fname, ext: string;
  lst: TStringList;
  i: NativeInt;
begin
  if fProject = nil then
    exit;
  //
  if fileExists(fProject.fileName) then
    dir := extractFilePath(fProject.fileName)
  else
    dir := '';
  if selectDirectory('sources', dir, dir, True, 0) then
  begin
    fProject.beginUpdate;
    lst := TStringList.Create;
    try
      listFiles(lst, dir, True);
      for i := 0 to lst.Count - 1 do
      begin
        fname := lst.Strings[i];
        ext := extractFileExt(fname);
        if dExtList.IndexOf(ext) <> -1 then
          fProject.addSource(fname);
      end;
    finally
      lst.Free;
      fProject.endUpdate;
    end;
  end;
end;

procedure TCEProjectInspectWidget.btnRemFoldClick(Sender: TObject);
var
  dir, fname: string;
  i: Integer;
begin
  if fProject = nil then
    exit;
  if Tree.Selected = nil then
    exit;
  if Tree.Selected.Parent <> fFileNode then
    exit;
  //
  fname := Tree.Selected.Text;
  i := fProject.Sources.IndexOf(fname);
  if i = -1 then
    exit;
  fname := fProject.getAbsoluteSourceName(i);
  dir := extractFilePath(fname);
  if not DirectoryExists(dir) then
    exit;
  //
  fProject.beginUpdate;
  for i := fProject.Sources.Count - 1 downto 0 do
    if extractFilePath(fProject.getAbsoluteSourceName(i)) = dir then
      fProject.Sources.Delete(i);
  fProject.endUpdate;
end;

procedure TCEProjectInspectWidget.btnRemFileClick(Sender: TObject);
var
  fname: string;
  i: NativeInt;
begin
  if fProject = nil then
    exit;
  if Tree.Selected = nil then
    exit;
  //
  if Tree.Selected.Parent = fFileNode then
  begin
    fname := Tree.Selected.Text;
    i := fProject.Sources.IndexOf(fname);
    if i > -1 then
    begin
      fProject.beginUpdate;
      fProject.Sources.Delete(i);
      fProject.endUpdate;
    end;
  end;
end;

procedure TCEProjectInspectWidget.FormDropFiles(Sender: TObject; const FileNames: array of String);
var
  fname: string;
  multidoc: ICEMultiDocHandler;
begin
  if fProject = nil then
    exit;
  multidoc := getMultiDocHandler;
  for fname in Filenames do
    if FileExists(fname) then
    begin
      multidoc.openDocument(fname);
      fProject.beginUpdate;
      fProject.addSource(fname);
      fProject.endUpdate;
    end;
end;

procedure TCEProjectInspectWidget.updateDelayed;
begin
  updateImperative;
end;

procedure TCEProjectInspectWidget.updateImperative;
var
  src, fold, conf: string;
  lst: TStringList;
  itm: TTreeNode;
  i: NativeInt;
begin
  fConfNode.DeleteChildren;
  fFileNode.DeleteChildren;
  fImpsNode.DeleteChildren;
  fInclNode.DeleteChildren;
  fXtraNode.DeleteChildren;
  if fProject = nil then
    exit;
  Tree.BeginUpdate;
  // display main sources
  for src in fProject.Sources do
  begin
    itm := Tree.Items.AddChild(fFileNode, src);
    itm.ImageIndex := 2;
    itm.SelectedIndex := 2;
  end;
  // display configurations
  for i := 0 to fProject.OptionsCollection.Count - 1 do
  begin
    conf := fProject.configuration[i].Name;
    if i = fProject.ConfigurationIndex then
      conf += ' (active)';
    itm := Tree.Items.AddChild(fConfNode, conf);
    itm.ImageIndex := 3;
    itm.SelectedIndex := 3;
  end;
  // display Imports (-J)
  for fold in FProject.currentConfiguration.pathsOptions.importStringPaths do
  begin
    if fold = '' then
      continue;
    fold := fProject.getAbsoluteFilename(fold);
    fold := symbolExpander.get(fold);
    itm := Tree.Items.AddChild(fImpsNode, fold);
    itm.ImageIndex := 5;
    itm.SelectedIndex := 5;
  end;
  fImpsNode.Collapse(False);
  // display Includes (-I)
  for fold in FProject.currentConfiguration.pathsOptions.importModulePaths do
  begin
    if fold = '' then
      continue;
    fold := fProject.getAbsoluteFilename(fold);
    fold := symbolExpander.get(fold);
    itm := Tree.Items.AddChild(fInclNode, fold);
    itm.ImageIndex := 5;
    itm.SelectedIndex := 5;
  end;
  fInclNode.Collapse(False);
  // display extra sources (external .lib, *.a, *.d)
  for src in FProject.currentConfiguration.pathsOptions.extraSources do
  begin
    if src = '' then
      continue;
    src := fProject.getAbsoluteFilename(src);
    src := symbolExpander.get(src);
    lst := TStringList.Create;
    try
      if listAsteriskPath(src, lst) then
        for src in lst do
        begin
          itm := Tree.Items.AddChild(fXtraNode, src);
          itm.ImageIndex := 2;
          itm.SelectedIndex := 2;
        end
      else
      begin
        itm := Tree.Items.AddChild(fXtraNode, src);
        itm.ImageIndex := 2;
        itm.SelectedIndex := 2;
      end;
    finally
      lst.Free;
    end;
  end;
  fXtraNode.Collapse(False);
  Tree.EndUpdate;
end;

{$ENDREGION --------------------------------------------------------------------}

end.
