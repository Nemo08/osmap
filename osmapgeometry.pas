(*
  OsMap components for offline rendering and routing functionalities
  based on OpenStreetMap data

  Copyright (C) 2019  Sergey Bodrov

  This source is ported from libosmscout library
  Copyright (C) 2009  Tim Teulings

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA

*)
(*
  OsMap geometry routines
GeoCoord:
  Coord -> TGeoCoord

Point:
  Point -> TGeoPoint

util\GeoBox
  GeoBox

util\Tiling
  OSMTileId
  OSMTileIdBox

util\Geometry (...)
*)

unit OsMapGeometry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, OsMapTypes;

const
  // Number of bytes needed to store a lat,lon coordinate pair.
  COORD_BUF_SIZE = 7;

  M_PI = 3.14159265358979323846;
  { Radius of the Earth in meters }
  EarthRadiusMeter = 6378137.0;
  { Extent of the earth in meter }
  EarthExtentMeter = 2 * M_PI * EarthRadiusMeter;
  { Width of a tile at the equator for zoom level 0 in meter (equal to extent of the earth at the equator }
  TileWidthZoom0Aquator = EarthExtentMeter;
  { DPI of a classical OSM tile }
  TileDPI = 96.0;

type
  //TII = SmallInt
  TLatitude   = type Double;  // Latitude, -90.0 ... 90.0
  TLongtitude = type Double;  // Longtitude,  -180.0 ... 180.0

  TGeoCoordBuffer = array [0..COORD_BUF_SIZE-1] of Byte;

  { Anonymous geographic point with coordinates. }
  TGeoPoint = object
  public
    Lat: TLatitude;    // Latitude,   -90.0 ... 90.0
    Lon: TLongtitude;  // Longtitude, -180.0 ... 180.0

    procedure Init(ALat: TLatitude; ALon: TLongtitude); inline;

    { Assign Lat and Lon from other geopoint }
    procedure Assign(const AValue: TGeoPoint); inline;
    { Assign only minimal values of Lat and Lon from both geopoints }
    procedure AssignMin(const AValue: TGeoPoint); inline;
    { Assign only maximal values of Lat and Lon from both geopoints }
    procedure AssignMax(const AValue: TGeoPoint); inline;

    { Return a string representation of the coordinate value in a human readable format. }
    function GetDisplayText(): string;

    { Returns a fast calculable unique id for the coordinate. Coordinates with have
      the same latitude and longitude value in the supported resolution wil have the same
      id.
      The id does not have any semantics regarding sorting. Coordinates with close ids
      do not need to be close in location. }
    function GetId(): TId;

    { Encode the coordinate value into a number (the number has hash character) }
    function GetHash(): TId;

    { Encode the coordinate value into a buffer. }
    procedure EncodeToBuffer(out ABuf: TGeoCoordBuffer);
    { Decode the coordinate value from a buffer }
    procedure DecodeFromBuffer(const ABuf: TGeoCoordBuffer);
    { Read coord binary value from stream }
    function ReadFromStream(AStream: TStream): Boolean;
    { Wtite coord binary value to stream }
    function WriteToStream(AStream: TStream): Boolean;

    { Return true if both coordinates are equal }
    function IsEqual(AValue: TGeoPoint): Boolean; inline;

    { Return true if both Latitude and Lingtitude have valid values }
    function IsValid(): Boolean;

    { Parse a textual representation of a geo coordinate from a string
      to an GeoCoord instance.

      The text should follow the following expression:

      [+|-|N|S] <coordinate> [N|S] [,] [+|-|W|E] <coordinate> [W|E]

      <coordinate> may have one of these formats:
       DDD[.DDDDD]
       DDD°[D[.DDD]'[D[.DDD]"]]

      The means:
      * You first define the latitude, then the longitude value
      * You can define with half you mean by either prefixing or postfixing
      the actual number with a hint
      * The hint can either be a sign ('-' or '+') or a direction ('N' and 'S'
      for latitude, 'E' or 'W' for longitude).

      Possibly in future more variants will be supported. It is guaranteed
      that the result of GetDisplayText() is successfully parsed. }
    function Parse(const AText: string): Boolean;

    { Get distance between two coordinates. The difference in height between the two points is neglected.
      ATarget: Target coordinate to measure distance }
    function GetDistance(const ATarget: TGeoPoint): TDistance;

    { Get coordinate of position + course and distance.
      ABearing: Target course in degree
      ADistance: Target distance }
    function Add(ABearing: Double; ADistance: TDistance): TGeoPoint;
  end;

  TGeoPointArray = array of TGeoPoint;

  function FindGeoPointInArray(const Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;
  function AppendGeoPointToArray(var Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;

type
  { TGeoPointItem }
  { A point is a identifiable (has an id) geo-coordinate. }
  TGeoPointItem = object
  public
    Serial: Byte;
    Coord: TGeoPoint;

    procedure Init(ASerial: Byte; const ACoords: TGeoPoint);

    { Returns a fast calculable unique id for the coordinate under consideration
      that different OSM nodes with the same coordinate will have different ids if the
      identity of the node is important - else the serial id will be 0.
      The id does not have any semantics regarding sorting. Coordinates with close ids
      do not need to be close in location. }
    function GetId(): TId;

    function GetCoordFromId(AId: TId): TGeoPoint;
    { True if Serial is not 0 }
    function IsRelevant(): Boolean;

    { Compare this and the other point for identity. Identity is defined
      as have the same coordinates and the same serial id per coordinate. }
    function IsIdentical(const AOther: TGeoPointItem): Boolean;
  end;

  TGeoPointItemArray = array of TGeoPointItem;

  { Appends item to array }
  //function AppendGeoPointToArray(var Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;


type
  { Anonymous geographic rectangular bounding box.

    The bounding box is defined by two coordinates (type GeoCoord) that span a
    (in coordinate space) rectangular area. }

  { TGeoBox }

  TGeoBox = object
  public
    MinCoord: TGeoPoint;
    MaxCoord: TGeoPoint;
    Valid: Boolean;

    { Invalidate the bounding Box }
    procedure Invalidate();
    { Assign a new rectangular area bases an two any coordinates defining the bounds. }
    procedure SetValue(const ACoord1, ACoord2: TGeoPoint); inline;
    { Copy data from other GeoBox }
    procedure Assign(const AOther: TGeoBox); inline;
    { Calculate the bounding box of the (non empty) geopoints array }
    procedure InitForPoints(const ANodes: TGeoPointArray;
      AFirstIndex: Integer = 0; ALastIndex: Integer = MaxInt);

    { Resize the bounding box to include the original bounding box and the given bounding box }
    procedure Include(const AOther: TGeoBox);

    { Resize the bounding box to include the original bounding box and the given point }
    procedure Include(const ACoord: TGeoPoint); overload;

    { Returns True if coordinate is within the bounding box.
      AOpenInterval - if True, an open interval for the GeoBox is assumed else a closed interval. }
    function IsIncludes(const ACoord: TGeoPoint; AOpenInterval: Boolean = True): Boolean;
    { Returns true, if both GeoBox instances intersect with each other
      AOpenInterval - if True, an open interval for the GeoBox is assumed else a closed interval. }
    function IsIntersects(const AOther: TGeoBox; AOpenInterval: Boolean = True): Boolean;
    { Create new GeoBox from intersection of this with other
      If not Intersects, invalid GeoBox is returned }
    function GetIntersection(const AOther: TGeoBox): TGeoBox;

    function GetCenter(): TGeoPoint;
    { Returns the width of the bounding box (maxLon-minLon) }
    function GetWidth(): Double; inline;
    { Returns the height of the bounding box (maxLat-minLat) }
    function GetHeight(): Double; inline;
    { Returns the size of the bounding box (width*height) }
    function GetSize(): Double; inline;

    function GetBottomLeft(): TGeoPoint;
    function GetBottomRight(): TGeoPoint;
    function GetTopLeft(): TGeoPoint;
    function GetTopRight(): TGeoPoint;

    { Read GeoBox value from stream }
    function ReadFromStream(AStream: TStream): Boolean;

    { Return a string representation of the coordinate value in a human readable format. }
    function GetDisplayText(): string;
    { Return an GeoBox based on the center and the radius [meters] of a circle around the center.
      The resulting box will cross the circle in its corners. }
    function BoxByCenterAndRadius(const ACenter: TGeoPoint; const ARadius: TDistance): TGeoBox;
  end;

  TSegmentGeoBox = record
    FromIndex: Integer;
    ToIndex: Integer;   // exclusive
    BBox: TGeoBox;
  end;

  TSegmentGeoBoxArray = array of TSegmentGeoBox;

  { OSMTile classes for handling OSM Tiles

    Class for representing OSM tiles and other data structures build on top
    of them.

    Note: OSM tiles walk from top left to bottom right over the earth.

    Note: OSM tiles only cover the region that is valid for the mercator
    projection

    See also: http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames for details about
    coordinate transformation behind OSM tiles. }

  { Representation of the x and y coordinate of a OSM tile.

    Note that OSM tile coordinates are only unique in content fo the
    zoom level of the tile. Because in most cases the zoom level beeing
    redundant we have defined OSMTile without the zoom level to save in memory
    space. }

  { TOSMTileId }

  TOSMTileId = object
  public
    X: LongWord;
    Y: LongWord;

    procedure Init(AX, AY: LongWord); inline;
    { Return the top left coordinate of the tile for given Magnification
     (these are relative to a magnification) }
    function GetTopLeftCoord(const AMagnification: TMagnification): TGeoPoint;
    { Return the bounding box of the given tile for given Magnification
     (these are relative to a magnification) }
    function GetBoundingBox(const AMagnification: TMagnification): TGeoBox;

    function GetDisplayText(): string;
  end;

  { A bounding box defined by two tile ids that span a rectangular region (in
    tile coordinate system) }
  TOSMTileIdBox = object
    MinTile: TOSMTileId ;
    MaxTile: TOSMTileId;

    function GetWidth(): LongWord;
    function GetHeight(): LongWord;
    function GetCount(): LongWord;

    { Return the bounding box of the region defined by the box for given Magnification }
    function GetBoundingBox(const AMagnification: TMagnification): TGeoBox;

    function GetDisplayText(): string;
  end;

{ Return TGeoCoord for given Latitude and Longtitude }
function GeoCoord(ALat: TLatitude; ALon: TLongtitude): TGeoPoint;

{ Return TGeoBox for given MinCoord and MaxCoord }
function GeoBox(const AMinCoord, AMaxCoord: TGeoPoint): TGeoBox;

{ Return TOSMTileId for given X and Y }
function OSMTileId(AX, AY: LongWord): TOSMTileId;

function GetOSMTile(const AMagnification: TMagnification; const ACoord: TGeoPoint): TOSMTileId;

{ Calculating Vincenty's inverse for getting the ellipsoidal distance
  of two points on earth. }
function GetEllipsoidalDistance(aLon, aLat, bLon, bLat: Double): TDistance;

function GetEllipsoidalDistance(const A, B: TGeoPoint): TDistance; overload;

function GetEllipsoidalDistanceCoord(const APosition: TGeoPoint; ABearing: Double;
                                  const ADistance: TDistance): TGeoPoint;


{ Calculate the bounding box of the (non empty) vector of geo coords }
{ see TGeoBox.InitForPoints() }
{function GetBoundingBoxForPoints(const ANodes: TGeoPointArray;
                        AFirstIndex: Integer = 0;
                        ALastIndex: Integer = MaxInt): TGeoBox; }

{ Returns true, if the lines defined by the given coordinates intersect. Returns the intersection coordinate. }
function GetLineIntersection(const A1, A2, B1, B2: TGeoPoint; out AIntersection: TGeoPoint): Boolean;

procedure Normalize(X, Y: Double; out NX, NY: Double); inline;

{ Calculates the determinant of the line between the given points. }
function Det(X1, Y1, X2, Y2: Double): Double; inline;

{ compute difference of two angles
  A - angle in radians in range -M_PI .. +M_PI
  B - angle in radians in range -M_PI .. +M_PI }
function AngleDiff(A, B: Double): Double;


var
  { Coordinates will be stored as unsigned long values in file.
    For the conversion the float value is shifted to positive
    value and afterwards multiplied by conversion factor
    to get long values without significant values after colon. }
  GlobalLonConversionFactor: Double;
  GlobalLatConversionFactor: Double;

implementation

uses Math, OsMapUtils;

{ For the calculations here see:
  http://en.wikipedia.org/wiki/Mercator_projection
  http://en.wikipedia.org/wiki/Web_Mercator
  http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames }

function fmod(a, b: Double): Double; inline;
begin
  Result := a - b * Int(a / b);
end;

{function AppendGeoPointToArray(var Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;
begin
  Result := Length(Arr);
  SetLength(Arr, Result + 1);
  Arr[Result] := AItem;
end; }

function FindGeoPointInArray(const Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(Arr) to High(Arr) do
  begin
    if Arr[i].IsEqual(AItem) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function AppendGeoPointToArray(var Arr: TGeoPointArray; const AItem: TGeoPoint): Integer;
begin
  Result := Length(Arr);
  SetLength(Arr, Result + 1);
  Arr[Result] := AItem;
end;

function GeoCoord(ALat: TLatitude; ALon: TLongtitude): TGeoPoint;
begin
  Result.Lon := ALon;
  Result.Lat := ALat;
end;

function GeoBox(const AMinCoord, AMaxCoord: TGeoPoint): TGeoBox;
begin
  Result.SetValue(AMinCoord, AMaxCoord);
end;

function OSMTileId(AX, AY: LongWord): TOSMTileId;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function GetOSMTile(const AMagnification: TMagnification; const ACoord: TGeoPoint): TOSMTileId;
var
  LatRad: Double;
begin
  LatRad := ACoord.Lat * M_PI / 180.0;

  Result.X := LongWord(Floor((ACoord.Lon + 180.0) / 360.0 * AMagnification.Magnification));
  Result.Y := LongWord(Floor((1.0 - ln( tan(LatRad) + 1.0 / cos(LatRad)) / M_PI) / 2.0 * AMagnification.Magnification));
end;

function GetEllipsoidalDistance(aLon, aLat, bLon, bLat: Double): TDistance;
var
  a, b, f, phi1, phi2, lambda1, lambda2, a2b2b2: Double;
  U1, sinU1, cosU1, U2, sinU2, cosU2: Double;
  sinU1sinU2, cosU1sinU2, sinU1cosU2, cosU1cosU2: Double;
  omega, lambda, sigma, deltasigma, lambda0: Double;
  sinlambda, coslambda, sin2sigma, sinsigma, cossigma: Double;
  sinalpha, alpha, cosalpha, cos2alpha, cos2sigmam: Double;
  ul2, cos2sigmam2, A1, B1, C1: Double;
  i: Integer;
begin
  a := 6378137.0;          // length of semi-major axis of the ellipsoid (radius at equator)
  b := 6356752.314245;     // length of semi-minor axis of the ellipsoid (radius at the poles)
  f := 1 / 298.257223563;  // WGS-84 ellipsiod
  phi1 := aLat * M_PI / 180;
  phi2 := bLat * M_PI / 180;
  lambda1 := aLon * M_PI / 180;
  lambda2 := bLon * M_PI / 180;
  a2b2b2 := (a * a - b * b) / (b * b);

  omega := lambda2 - lambda1;

  U1 := arctan((1.0 - f) * tan(phi1));
  sincos(U1, sinU1, cosU1);

  U2 := arctan((1.0 - f) * tan(phi2));
  sincos(U2, sinU2, cosU2);

  sinU1sinU2 := sinU1 * sinU2;
  cosU1sinU2 := cosU1 * sinU2;
  sinU1cosU2 := sinU1 * cosU2;
  cosU1cosU2 := cosU1 * cosU2;

  lambda := omega;

  A1 := 0.0;
  B1 := 0.0;
  sigma := 0.0;
  deltasigma := 0.0;

  for i := 0 to 10 do
  begin
    lambda0 := lambda;

    sincos(lambda, sinlambda, coslambda);

    sin2sigma := (cosU2 * sinlambda * cosU2 * sinlambda)
               + (cosU1sinU2 - sinU1cosU2 * coslambda)
               * (cosU1sinU2 - sinU1cosU2 * coslambda);

    sinsigma := sqrt(sin2sigma);

    cossigma := sinU1sinU2 + (cosU1cosU2 * coslambda);

    sigma := arctan2(sinsigma, cossigma);

    if (sin2sigma = 0.0) then
      sinalpha := 0.0
    else
      sinalpha := cosU1cosU2 * sinlambda / sinsigma;

    alpha := arcsin(sinalpha);
    cosalpha := cos(alpha);
    cos2alpha := cosalpha * cosalpha;

    if (cos2alpha = 0.0) then
      cos2sigmam := 0.0
    else
      cos2sigmam := cossigma - 2 * sinU1sinU2 / cos2alpha;

    ul2 := cos2alpha * a2b2b2;

    cos2sigmam2 := cos2sigmam * cos2sigmam;

    A1 := 1.0 + ul2 / 16384 * (4096 + ul2
        * (-768 + ul2 * (320 - 175 * ul2)));

    B1 := ul2 / 1024 * (256 + ul2 * (-128 + ul2 * (74 - 47 * ul2)));

    deltasigma := B1 * sinsigma * (cos2sigmam + B1 / 4
                * (cossigma * (-1 + 2 * cos2sigmam2) - B1 / 6
                * cos2sigmam * (-3 + 4 * sin2sigma)
                * (-3 + 4 * cos2sigmam2)));

    C1 := f / 16 * cos2alpha * (4 + f * (4 - 3 * cos2alpha));

    lambda := omega + (1 - C1) * f * sinalpha
            * (sigma + C1 * sinsigma * (cos2sigmam + C1
            * cossigma * (-1 + 2 * cos2sigmam2)));

    if ((i > 1) and (abs((lambda - lambda0) / lambda) < 0.0000000000001)) then
      Break;

  end;

  Result := b * A1 * (sigma - deltasigma);
end;

procedure CalcEllipsoidalDistance(Lat1, Lon1, ABearing: Double;
                            const ADistance: TDistance;
                            out lat2, lon2: Double);
var
  a, b, f, A1, B1, C, L: Double;
  distanceAsMeter: Double;
  alpha1, cosAlpha1, sinAlpha1: Double;
  tanU1, cosU1, sinU1: Double;
  sigma1, sinAlpha, cosSqAlpha, uSq: Double;
  sigma, sinSigma, cosSigma, cos2SigmaM, sigmaP: Double;
  deltaSigma, tmp, lambda: Double;
begin
  { See https://en.wikipedia.org/wiki/Vincenty%27s_formulae }

  { local variable definitions }

  lat1 := lat1 * M_PI / 180;
  lon1 := lon1 * M_PI / 180;

  // WGS-84 ellipsiod
  a := 6378137.0;       // length of semi-major axis of the ellipsoid (radius at equator)
  b := 6356752.314245;  // length of semi-minor axis of the ellipsoid (radius at the poles)
  f := 1/298.257223563; // flattening of the ellipsoid
  distanceAsMeter := ADistance;

  alpha1 := ABearing * M_PI / 180;

  tanU1 := (1-f) * tan(lat1);
  cosU1 := 1 / sqrt((1 + tanU1 * tanU1));
  sinU1 := tanU1 * cosU1;

  cosAlpha1 := cos(alpha1);
  sinAlpha1 := sin(alpha1);

  sigma1 := arctan2(tanU1, cosAlpha1);
  sinAlpha := cosU1 * sinAlpha1;

  cosSqAlpha := 1 - sinAlpha * sinAlpha;
  uSq := cosSqAlpha * (a * a - b * b) / (b * b);

  A1 := 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  B1 := uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));

  sigma := distanceAsMeter / (b * A1);

  repeat
    cos2SigmaM := cos(2 * sigma1 + sigma);

    sinSigma := sin(sigma);
    cosSigma := cos(sigma);

    deltaSigma := B1 * sinSigma * (cos2SigmaM + B1 / 4
                * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
                - B1 / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma)
                * (-3 + 4 * cos2SigmaM * cos2SigmaM)));
    sigmaP := sigma;
    sigma := distanceAsMeter / (b * A1) + deltaSigma;
  until (abs(sigma - sigmaP) > 1e-12);

  tmp := sinU1 * sinSigma - cosU1 * cosSigma * cosAlpha1;

  lat2 := arctan2(sinU1 * cosSigma + cosU1 * sinSigma * cosAlpha1,
               (1-f) * sqrt(sinAlpha * sinAlpha + tmp * tmp));
  lambda := arctan2(sinSigma * sinAlpha1,
                        cosU1 * cosSigma - sinU1 * sinSigma * cosAlpha1);
  C := f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
  L := lambda - (1-C) * f * sinAlpha * (sigma + C * sinSigma
     * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));

  lon2 := fmod(lon1 + L + 3 * M_PI, 2 * M_PI) - M_PI;

  lat2 := lat2 * 180.0 / M_PI;
  lon2 := lon2 * 180.0 / M_PI;
end;

function GetEllipsoidalDistance(const A, B: TGeoPoint): TDistance;
begin
  Result := GetEllipsoidalDistance(A.Lon, A.Lat, B.Lon, B.Lat);
end;

function GetEllipsoidalDistanceCoord(const APosition: TGeoPoint; ABearing: Double;
                                const ADistance: TDistance): TGeoPoint;
begin
  CalcEllipsoidalDistance(APosition.Lat,
                         APosition.Lon,
                         ABearing,
                         ADistance,
                         Result.Lat, Result.Lon);

end;

function GetLineIntersection(const A1, A2, B1, B2: TGeoPoint; out AIntersection: TGeoPoint): Boolean;
var
  denr, ua_numr, ub_numr, ua, ub: Double;
  aBox, bBox: TGeoBox;
begin
  if A1.IsEqual(B1) or A1.IsEqual(B2) then
  begin
    AIntersection.Assign(A1);
    Exit(True);
  end;

  if A2.IsEqual(B1) or A2.IsEqual(B2) then
  begin
    AIntersection.Assign(A2);
    Exit(True);
  end;

  if A1.IsEqual(A2) and B1.IsEqual(B2) then
  begin
    // two different zero size vectors can't intersects
    Exit(False);
  end;

  // for geographic, expect point.x=lon and point.y=lat

  // see https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
  // and http://www.geeksforgeeks.org/orientation-3-ordered-points/

  // denominator < 0  : left angle
  // denominator == 0 : parallels
  // denominator > 0  : right angle
  denr := (B2.Lat - B1.Lat) * (A2.Lon - A1.Lon)
        - (B2.Lon - B1.Lon) * (A2.Lat - A1.Lat);

  ua_numr := (B2.Lon - B1.Lon) * (A1.Lat - B1.Lat)
           - (B2.Lat - B1.Lat) * (A1.Lon - B1.Lon);

  ub_numr := (A2.Lon - A1.Lon) * (A1.Lat - B1.Lat)
           - (A2.Lat - A1.Lat) * (A1.Lon - B1.Lon);

  if (denr = 0.0) then
  begin
    if (ua_numr = 0.0) and (ub_numr = 0.0) then
    begin
      // two lines are on one straight line, check the bounds
      aBox.SetValue(GeoCoord(A1.Lat, A1.Lon),
                    GeoCoord(A2.Lat, A2.Lon));
      bBox.SetValue(GeoCoord(B1.Lat, B1.Lon),
                    GeoCoord(B2.Lat, B2.Lon));
      if bBox.IsIncludes(A1, False) then
      begin
        AIntersection.Init(A1.Lat, A1.Lon);
        Exit(True);
      end;
      if bBox.IsIncludes(A2, False) then
      begin
        AIntersection.Init(A2.Lat, A2.Lon);
        Exit(True);
      end;
      if aBox.IsIncludes(B1, False) then
      begin
        AIntersection.Init(B1.Lat, B1.Lon);
        Exit(True);
      end;
      if aBox.IsIncludes(B2, False) then
      begin
        AIntersection.Init(B2.Lat, B2.Lon);
        Exit(True);
      end;

      Exit(False);
    end
    else
      Exit(False);
  end;

  ua := ua_numr / denr;
  ub := ub_numr / denr;

  if (ua >= 0.0) and (ua <= 1.0) and (ub >= 0.0) and (ub <= 1.0)  then
  begin
    AIntersection.Lat := A1.Lat + ua * (A2.Lat - A1.Lat);
    AIntersection.Lon := A1.Lon + ua * (A2.Lon - A1.Lon);
    Exit(True);
  end;

  Result := False;
end;

procedure Normalize(X, Y: Double; out NX, NY: Double);
var
  Len: Double;
begin
  Len := sqrt((X * X) + (Y * Y));
  NX := X / Len;
  NY := Y / Len;
end;

function Det(X1, Y1, X2, Y2: Double): Double;
begin
  Result := (X1 * Y2) - (Y1 * X2);
end;

function AngleDiff(A, B: Double): Double;
begin
  Result := abs(a - b);
  if Result > M_PI then
    Result := (2 * M_PI) - Result;
end;

{ TGeoPoint }

procedure TGeoPoint.Init(ALat: TLatitude; ALon: TLongtitude);
begin
  Lat := ALat;
  Lon := ALon;
end;

procedure TGeoPoint.Assign(const AValue: TGeoPoint);
begin
  Lat := AValue.Lat;
  Lon := AValue.Lon;
end;

procedure TGeoPoint.AssignMin(const AValue: TGeoPoint);
begin
  Lat := Min(Lat, AValue.Lat);
  Lon := Min(Lon, AValue.Lon);
end;

procedure TGeoPoint.AssignMax(const AValue: TGeoPoint);
begin
  Lat := Max(Lat, AValue.Lat);
  Lon := Max(Lon, AValue.Lon);
end;

function TGeoPoint.GetDisplayText(): string;
begin
  Result := Format('%.5d', [Abs(Lat)]);

  if (Lat >= 0) then
    Result := Result + ' N '
  else
    Result := Result + ' S ';

  Result := Result + Format('%.5d', [Abs(Lon)]);

  if (Lon >= 0) then
    Result := Result + ' E'
  else
    Result := Result + ' W';
end;

function TGeoPoint.GetId(): TId;
var
  LatValue, LonValue: Int64;
begin
  LatValue := Round((Lat + 90.0) * GlobalLatConversionFactor);
  LonValue := Round((Lon + 180.0) * GlobalLonConversionFactor);

  Result := ((LatValue and $000000ff) shl  8)  // 0 => 8
          + ((LonValue and $000000ff) shl  0)  // 0 => 0
          + ((LatValue and $0000ff00) shl 16)  // 8 => 24
          + ((LonValue and $0000ff00) shl  8)  // 8 => 16
          + ((LatValue and $00ff0000) shl 24)  // 16 => 40
          + ((LonValue and $00ff0000) shl 16)  // 16 => 32
          + ((LatValue and $07000000) shl 27)  // 24 => 51
          + ((LonValue and $07000000) shl 24); // 24 => 48
end;

function TGeoPoint.GetHash(): TId;
var
  LatValue, LonValue: Int64;
  i: Integer;
begin
  LatValue := Round((Lat + 90.0) * GlobalLatConversionFactor);
  LonValue := Round((Lon + 180.0) * GlobalLonConversionFactor);
  Result := 0;

  for i := 26 downto 0 do
  begin
    Result := Result shl 1;
    Result := Result + ((LatValue shr i) and $01);

    Result := Result shl 1;
    Result := Result + ((LonValue shr i) and $01);
  end;
end;

procedure TGeoPoint.EncodeToBuffer(out ABuf: TGeoCoordBuffer);
var
  LatValue, LonValue: Int64;
begin
  LatValue := Round((Lat + 90.0) * GlobalLatConversionFactor);
  LonValue := Round((Lon + 180.0) * GlobalLonConversionFactor);

  ABuf[0] := ((LatValue shr  0) and $FF);
  ABuf[1] := ((LatValue shr  8) and $FF);
  ABuf[2] := ((LatValue shr 16) and $FF);

  ABuf[3] := ((LonValue shr  0) and $FF);
  ABuf[4] := ((LonValue shr  8) and $FF);
  ABuf[5] := ((LonValue shr 16) and $FF);

  ABuf[6] := ((LatValue shr 24) and $07) or ((LonValue shr 20) and $70);
end;

procedure TGeoPoint.DecodeFromBuffer(const ABuf: TGeoCoordBuffer);
var
  LatValue, LonValue: LongWord;
begin
  LatValue := (ABuf[0] shl  0)
           or (ABuf[1] shl  8)
           or (ABuf[2] shl 16)
           or ((ABuf[6] and $0F) shl 24);

  LonValue := (ABuf[3] shl  0)
           or (ABuf[4] shl  8)
           or (ABuf[5] shl 16)
           or ((ABuf[6] and $F0) shl 20);

  Lat := LatValue / GlobalLatConversionFactor - 90.0;
  Lon := LonValue / GlobalLonConversionFactor - 180.0;
end;

function TGeoPoint.ReadFromStream(AStream: TStream): Boolean;
var
  Buf: TGeoCoordBuffer;
  n: Integer;
begin
  Assert(Assigned(AStream));
  Result := False;
  Buf[0] := 0; // eliminate warning
  n := AStream.Read(Buf, SizeOf(Buf));
  if n = SizeOf(Buf) then
  begin
    DecodeFromBuffer(Buf);
    Result := True;
  end;
end;

function TGeoPoint.WriteToStream(AStream: TStream): Boolean;
var
  Buf: TGeoCoordBuffer;
  n: Integer;
begin
  Assert(Assigned(AStream));
  EncodeToBuffer(Buf);
  n := AStream.Write(Buf, SizeOf(Buf));
  Result := (n = SizeOf(Buf));
end;

function TGeoPoint.IsEqual(AValue: TGeoPoint): Boolean;
begin
  Result := (Lat = AValue.Lat) and (Lon = AValue.Lon);
end;

function TGeoPoint.IsValid(): Boolean;
begin
  Result := (Lat <= 90.0) and (Lat >= -90.0)
        and (Lon <= 180.0) and (Lon >= -180.0);
end;

{ for TGeoPoint.Parse() }
function EatWhitespace(const AText: string; APos: Integer): Integer;
begin
  while (APos < Length(AText)) and (Copy(AText, APos, 1) = ' ') do
  begin
    Inc(APos);
  end;
  Result := APos;
end;

{ for TGeoPoint.Parse(), ScanCoordinate() }
function ScanNumber(const AText: string; var APos: Integer; var AValue: Double; AMaxDigits: Integer): Boolean;
var
  n, DigitsCount: Integer;
  Factor: Double;
begin
  Result := False;
  AValue := 0.0;
  DigitsCount := 0;

  if APos < 0 then Exit;

  while (APos <= Length(AText)) do
  begin
    n := Ord(AText[APos]) - Ord('0');
    if (n >= 0) and (n < 10) then
    begin
      Inc(DigitsCount);
      AValue := (AValue * 10) + n;
      if DigitsCount > AMaxDigits then
        Exit;
    end
    else
      Break;
    Inc(APos);
  end;

  if DigitsCount = 0 then
    Exit;

  // TODO: Scan Digit and Co

  if (APos < Length(AText)) and (Pos(AText[APos], '.,') > 0) then
  begin
    Inc(APos);

    Factor := 10;

    while (APos <= Length(AText)) do
    begin
      n := Ord(AText[APos]) - Ord('0');
      if (n < 0) or (n > 9) then
        Break;

      Inc(DigitsCount);
      AValue := AValue + (n / Factor);
      Factor := Factor * 10;
      Inc(APos);
    end;
  end;

  Result := True;
end;

{ for TGeoPoint.Parse() }
function ScanCoordinate(const AText: string; var APos: Integer; var AValue: Double; AMaxDigits: Integer): Boolean;
var
  n, TextLen: Integer;
  Minutes, Seconds: Double;
begin
  Result := ScanNumber(AText, APos, AValue, AMaxDigits);
  if (not Result) then
    Exit;

  TextLen := Length(AText);
  if (APos >= TextLen) or (APos+1 < TextLen) then
    Exit;

  Result := False;

  if (Ord(AText[APos]) = 248)  // ASCII Latin Small Letter O with stroke
  or (Ord(AText[APos]) = $B0)  // ASCII Degree symbol
  or (Ord(AText[APos]) = $BA)  // ASCII Masculine ordinal indicator
  or ((Ord(AText[APos]) = $C2) and (Ord(AText[APos+1]) = $B0)) // UTF8 sequence 0xc2b0: degree sign (°)
  then
  begin
    if (Ord(AText[APos]) = $C2) then
      Inc(APos, 2)
    else
      Inc(APos, 1);

    // try pattern:
    // DDD°[D[.DDD]'[D[.DDD]"]]
    // parse minutes
    if (APos < TextLen) then
      n := Ord(AText[APos]) - Ord('0')
    else
      n := -1;

    if (n >= 0) and (n < 10) then
    begin
      Minutes := 0;
      if (not ScanNumber(AText, APos, Minutes, 2)) then
        Exit;

      if (APos < TextLen) and (AText[APos] = '''') then
      begin
        AValue := AValue + (Minutes / 60.0);
        Inc(APos);

        // parse seconds
        if (APos < TextLen) then
          n := Ord(AText[APos]) - Ord('0')
        else
          n := -1;

        if (n >= 0) and (n < 10) then
        begin
          Seconds := 0;
          if (not ScanNumber(AText, APos, Seconds, 2)) then
            Exit;

          if (APos < TextLen) and (AText[APos] = '"') then
          begin
            AValue := AValue + (Seconds / 3600.0);
            Inc(APos);
          end
          else
            Exit;
        end;
      end
      else
        Exit;
    end;
  end;

  Result := True;
end;

function TGeoPoint.Parse(const AText: string): Boolean;
var
  CurPos, TextLen: Integer;
  TmpLat, TmpLon: Double;
  IsLatPos, IsLatDirectionGiven: Boolean;
  IsLonPos, IsLonDirectionGiven: Boolean;

  function _EatWhitespaces(): Boolean;
  begin
    while (CurPos <= TextLen) and (AText[CurPos] = ' ') do
    begin
      Inc(CurPos);
    end;
    Result := (CurPos <= TextLen)
  end;

begin
  Result := False;
  CurPos := 1;
  TextLen := Length(AText);
  TmpLat := 0;
  IsLatPos := True;
  IsLatDirectionGiven := False;

  TmpLon := 0;
  IsLonPos := True;
  IsLonDirectionGiven := False;

  if not _EatWhitespaces() then
    Exit;

  // === Latitude

  case AText[CurPos] of
    'N', '+':
    begin
      IsLatPos := True;
      IsLatDirectionGiven := True;
      Inc(CurPos);
    end;

    'S', '-':
    begin
      IsLatPos := False;
      IsLatDirectionGiven := True;
      Inc(CurPos);
    end;
  end;

  if not _EatWhitespaces() then
    Exit;

  if (not ScanCoordinate(AText, CurPos, TmpLat, 2)) then
    Exit;

  if not _EatWhitespaces() then
    Exit;

  if (AText[CurPos] = 'N') then
  begin
    if IsLatDirectionGiven then
      Exit;

    IsLatPos := True;
    IsLatDirectionGiven := true;
    Inc(CurPos);
  end
  else if (AText[CurPos] = 'S') then
  begin
    if IsLatDirectionGiven then
      Exit;

    IsLatPos := False;
    IsLatDirectionGiven := True;
    Inc(CurPos);
  end;

  if not _EatWhitespaces() then
    Exit;

  if (not IsLatPos) then
    TmpLat := -TmpLat;

  // === Longitude

  case AText[CurPos] of
    'E', '+':
    begin
      IsLonPos := True;
      IsLonDirectionGiven := True;
      Inc(CurPos);
    end;

    'W', '-':
    begin
      IsLonPos := False;
      IsLonDirectionGiven := True;
      Inc(CurPos);
    end;

    ',':
    begin
      Inc(CurPos);
    end;
  end;

  if not _EatWhitespaces() then
    Exit;

  if (not ScanCoordinate(AText, CurPos, TmpLon, 3)) then
    Exit;

  if _EatWhitespaces() then
  begin
    case AText[CurPos] of
      'E':
      begin
        if IsLonDirectionGiven then
          Exit;

        IsLonPos := True;
        IsLonDirectionGiven := True;
        Inc(CurPos);
      end;

      'W':
      begin
        if IsLonDirectionGiven then
          Exit;

        IsLonPos := False;
        IsLonDirectionGiven := True;
        Inc(CurPos);
      end;
    end;
  end;

  if (not IsLonPos) then
    TmpLon := -TmpLon;

  if not _EatWhitespaces() then
  begin
    // no more characters left
    Lat := TmpLat;
    Lon := TmpLon;

    Result := True;
  end;
end;

function TGeoPoint.GetDistance(const ATarget: TGeoPoint): TDistance;
begin
  Result := GetEllipsoidalDistance(Self, ATarget);
end;

function TGeoPoint.Add(ABearing: Double; ADistance: TDistance): TGeoPoint;
begin
  if ADistance = 0.0 then
    Result := Self
  else
    Result := GetEllipsoidalDistanceCoord(Self, ABearing, ADistance);
end;

{ TGeoPointItem }

procedure TGeoPointItem.Init(ASerial: Byte; const ACoords: TGeoPoint);
begin
  Serial := ASerial;
  Coord := ACoords;
end;

function TGeoPointItem.GetId(): TId;
begin
  Result := Coord.GetId();
  Result := Result shl 8;
  Result := Result or Serial;
end;

function TGeoPointItem.GetCoordFromId(AId: TId): TGeoPoint;
var
  LatValue, LonValue: Int64;
begin
  AId := AId shr 8;

  LatValue := ((AId shr 8) and $ff)
            + (((AId shr 24) and $ff) shl 8)
            + (((AId shr 40) and $ff) shl 16)
            + (((AId shr 51) and $07) shl 24);
  LonValue := ((AId shr 0) and $ff)
            + (((AId shr 16) and $ff) shl 8)
            + (((AId shr 32) and $ff) shl 16)
            + (((AId shr 48) and $07) shl 24);

  Result.Init(LatValue / GlobalLatConversionFactor - 90.0,
              LonValue / GlobalLonConversionFactor - 180.0);
end;

function TGeoPointItem.IsRelevant(): Boolean;
begin
  Result := (Serial <> 0);
end;

function TGeoPointItem.IsIdentical(const AOther: TGeoPointItem): Boolean;
begin
  Result := (Serial = AOther.Serial) and Coord.IsEqual(AOther.Coord);
end;

{ TGeoBox }

procedure TGeoBox.Invalidate();
begin
  MinCoord.Init(0.0, 0.0);
  MaxCoord.Init(0.0, 0.0);
  Valid := False;
end;

procedure TGeoBox.SetValue(const ACoord1, ACoord2: TGeoPoint);
begin
  MinCoord.Lat := Min(ACoord1.Lat, ACoord2.Lat);
  MinCoord.Lon := Min(ACoord1.Lon, ACoord2.Lon);
  MaxCoord.Lat := Max(ACoord1.Lat, ACoord2.Lat);
  MaxCoord.Lon := Max(ACoord1.Lon, ACoord2.Lon);
  Valid := True;
end;

procedure TGeoBox.Assign(const AOther: TGeoBox);
begin
  SetValue(AOther.MinCoord, AOther.MaxCoord);
end;

procedure TGeoBox.InitForPoints(const ANodes: TGeoPointArray;
  AFirstIndex: Integer; ALastIndex: Integer);
var
  i: Integer;
begin
  Assert(Length(ANodes) > 0);
  Valid := False;
  if Length(ANodes) = 0 then
    Exit;

  if ALastIndex >= Length(ANodes) then
    ALastIndex := Length(ANodes)-1;

  MinCoord := ANodes[0];
  MaxCoord := ANodes[0];

  for i := AFirstIndex to ALastIndex do
  begin
    MinCoord.AssignMin(ANodes[i]);
    MaxCoord.AssignMax(ANodes[i]);
  end;
  Valid := True;
end;

procedure TGeoBox.Include(const AOther: TGeoBox);
begin
  if not AOther.Valid then
    Exit;

  if not Valid then
  begin
    Assign(AOther);
  end
  else
  begin
    MinCoord.AssignMin(AOther.MinCoord);
    MaxCoord.AssignMax(AOther.MaxCoord);
  end;
end;

procedure TGeoBox.Include(const ACoord: TGeoPoint);
begin
  if not Valid then
  begin
    MinCoord := ACoord;
    MaxCoord := ACoord;
    Valid := True;
  end
  else
  begin
    MinCoord.AssignMin(ACoord);
    MaxCoord.AssignMax(ACoord);
  end;
end;

function TGeoBox.IsIncludes(const ACoord: TGeoPoint; AOpenInterval: Boolean): Boolean;
begin
  Result := False;
  if not Valid then
    Exit;

  if AOpenInterval then
  begin
    Result := (MinCoord.Lat <= ACoord.Lat)
          and (MaxCoord.Lat >  ACoord.Lat)
          and (MinCoord.Lon <= ACoord.Lon)
          and (MaxCoord.Lon >  ACoord.Lon);
  end
  else
  begin
    Result := (MinCoord.Lat <= ACoord.Lat)
          and (MaxCoord.Lat >= ACoord.Lat)
          and (MinCoord.Lon <= ACoord.Lon)
          and (MaxCoord.Lon >= ACoord.Lon);
  end;
end;

function TGeoBox.IsIntersects(const AOther: TGeoBox; AOpenInterval: Boolean): Boolean;
begin
  Result := False;
  if (not Valid) or (not AOther.Valid) then
    Exit;

  if AOpenInterval then
  begin
    Result := (AOther.MaxCoord.Lon <  MinCoord.Lon)
          and (AOther.MinCoord.Lon >= MaxCoord.Lon)
          and (AOther.MaxCoord.Lat <  MinCoord.Lat)
          and (AOther.MinCoord.Lat >= MaxCoord.Lat);
  end
  else
  begin
    Result := (AOther.MaxCoord.Lon <  MinCoord.Lon)
          and (AOther.MinCoord.Lon >  MaxCoord.Lon)
          and (AOther.MaxCoord.Lat <  MinCoord.Lat)
          and (AOther.MinCoord.Lat >  MaxCoord.Lat);
  end;
end;

function TGeoBox.GetIntersection(const AOther: TGeoBox): TGeoBox;
var
  CornerMin, CornerMax: TGeoPoint;
begin
  if (not Valid) or (not AOther.Valid) or (not IsIntersects(AOther)) then
  begin
    Result.Invalidate();
  end
  else
  begin
    CornerMin.Init(Max(AOther.MinCoord.Lat, MinCoord.Lat),
                   Max(AOther.MinCoord.Lon, MinCoord.Lon));

    CornerMax.Init(Min(AOther.MaxCoord.Lat, MaxCoord.Lat),
                   Min(AOther.MaxCoord.Lon, MaxCoord.Lon));

    Result.SetValue(CornerMin, CornerMax);
  end;
end;

function TGeoBox.GetCenter(): TGeoPoint;
begin
  Result.Lat := (MinCoord.Lat + MaxCoord.Lat) / 2;
  Result.Lon := (MinCoord.Lon + MaxCoord.Lon) / 2;
end;

function TGeoBox.GetWidth(): Double;
begin
  Result := MaxCoord.Lon - MinCoord.Lon;
end;

function TGeoBox.GetHeight(): Double;
begin
  Result := MaxCoord.Lat - MinCoord.Lat;
end;

function TGeoBox.GetSize(): Double;
begin
  Result := GetWidth() * GetHeight();
end;

function TGeoBox.GetBottomLeft(): TGeoPoint;
begin
  Result := MinCoord;
end;

function TGeoBox.GetBottomRight(): TGeoPoint;
begin
  Result.Init(MinCoord.Lat, MaxCoord.Lon);
end;

function TGeoBox.GetTopLeft(): TGeoPoint;
begin
  Result.Init(MaxCoord.Lat, MinCoord.Lon);
end;

function TGeoBox.GetTopRight(): TGeoPoint;
begin
  Result := MaxCoord;
end;

function TGeoBox.ReadFromStream(AStream: TStream): Boolean;
begin
  Assert(Assigned(AStream));
  Result := MinCoord.ReadFromStream(AStream) and MaxCoord.ReadFromStream(AStream);
  Valid := MinCoord.IsValid() and MaxCoord.IsValid();
end;

function TGeoBox.GetDisplayText(): string;
begin
  Result := '[' + MinCoord.GetDisplayText() + ' - ' + MaxCoord.GetDisplayText() + ']';
end;

function TGeoBox.BoxByCenterAndRadius(const ACenter: TGeoPoint;
  const ARadius: TDistance): TGeoBox;
var
  topLat, botLat, leftLon, rightLon: Double;
begin
  CalcEllipsoidalDistance(ACenter.Lat,
                         ACenter.Lon,
                         315.0,
                         ARadius,
                         topLat,
                         leftLon);

  CalcEllipsoidalDistance(ACenter.Lat,
                         ACenter.Lon,
                         135.0,
                         ARadius,
                         botLat,
                         rightLon);

  Result.SetValue(GeoCoord(topLat, leftLon),
                  GeoCoord(botLat, rightLon));
end;

{ TOSMTileId }

procedure TOSMTileId.Init(AX, AY: LongWord);
begin
  X := AX;
  Y := AY;
end;

function TOSMTileId.GetTopLeftCoord(const AMagnification: TMagnification): TGeoPoint;
var
  n: Double;
begin
  n := M_PI - 2.0 * M_PI * Y / AMagnification.Magnification;

  Result.Lat := 180.0 / M_PI * arctan(0.5 * (exp(n) - exp(-n)));
  Result.Lon := Y / AMagnification.Magnification * 360.0 - 180.0;
end;

function TOSMTileId.GetBoundingBox(const AMagnification: TMagnification): TGeoBox;
begin
  Assert( (X < High(LongWord)) and (Y < High(LongWord)) );
  Result.MinCoord := GetTopLeftCoord(AMagnification);
  Result.MaxCoord := OSMTileId(X+1, Y+1).GetTopLeftCoord(AMagnification);
end;

function TOSMTileId.GetDisplayText(): string;
begin
  Result := IntToStr(X) + ',' + IntToStr(Y);
end;

{ TOSMTileIdBox }

function TOSMTileIdBox.GetWidth(): LongWord;
begin
  Result := MaxTile.X - MinTile.X + 1;
end;

function TOSMTileIdBox.GetHeight(): LongWord;
begin
  Result := MaxTile.Y - MinTile.Y + 1;
end;

function TOSMTileIdBox.GetCount(): LongWord;
begin
  Result := GetWidth() * GetHeight();
end;

function TOSMTileIdBox.GetBoundingBox(const AMagnification: TMagnification): TGeoBox;
begin
  Result.MinCoord := MinTile.GetTopLeftCoord(AMagnification);
  Result.MaxCoord := OSMTileId(MaxTile.X+1, MaxTile.Y+1).GetTopLeftCoord(AMagnification);
end;

function TOSMTileIdBox.GetDisplayText(): string;
begin
  Result := '[' + MinTile.GetDisplayText() + ' - ' + MaxTile.GetDisplayText() + ']';
end;

initialization

GlobalLatConversionFactor := 134217727.0 / 180.0; // 27 Bit
GlobalLonConversionFactor := 134217727.0 / 360.0; // 27 Bit

end.

