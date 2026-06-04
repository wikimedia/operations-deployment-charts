import unittest
import yaml

from os import path

from ..data import *

TEST_DIR = path.dirname(__file__)
TEST_DATA = {
    "just_none": None,
    "some_bool": True,
    "some_int": 1234,
    "some_string": "abcd",
    "string_list": [ "a", "b", "c" ],
    "nested_dict": {
        "foo": { "x": 1, "y": [ 1, 2, 3 ] },
        "bar": { "x": 2, "y": [ 5, 6, 7 ] },
    },
    "dict_list": [
        { "foo": "S", "bar": 2 },
        { "foo": "T", "bar": 6 },
    ],
}

def unwrap(v):
    if isinstance(v, HelmData):
        return unwrap( v.values )

    if isinstance(v, list):
        return [ unwrap(w) for w in v ]

    if isinstance(v, dict):
        return { k: unwrap(w) for k, w in v.items() }

    return v

class MyStruct (HelmData):
    pass

class HelmDataTest(unittest.TestCase):

    def test_empty(self):
        e = HelmData()
        self.assertTrue( e.empty() )

        s = HelmData(TEST_DATA)
        self.assertFalse( s.empty() )

    def test_dict_access(self):
        s = HelmData(TEST_DATA)

        self.assertIs( s["just_none"], None )
        self.assertEqual( s["some_string"], "abcd" )
        self.assertEqual( s["nested_dict"]["foo"]["x"], 1 )

        self.assertEqual( list(s), list(TEST_DATA) )
        self.assertEqual( s.keys(), TEST_DATA.keys() ) # test keys()
        self.assertEqual( [ k for k in s ], [ k for k in TEST_DATA.keys() ] ) # test __iter__()
        self.assertEqual( [ item[0] for item in s.items() ], [ k for k in TEST_DATA.keys() ] )

        self.assertTrue( "string_list" in s )
        self.assertFalse( "xyzzy" in s )

        with self.assertRaises(KeyError):
            _ = s["xyzzy"]

    def test_object_access(self):
        s = HelmData(TEST_DATA)

        self.assertIs( s.just_none, None )
        self.assertEqual( s.some_string, "abcd" )
        self.assertEqual( s.nested_dict.foo.x, 1 )

        with self.assertRaises(AttributeError):
            _ = s.xyzzy

    def test_get(self):
         s = HelmData(TEST_DATA)

         self.assertIs( s.get("just_none"), None )
         self.assertIs( s.get("just_none", "xyz"), None )

         self.assertEqual( s.get("some_string"), "abcd" )
         self.assertEqual( s.get("some_string", "xyz"), "abcd" )

         self.assertEqual( s.get("nested_dict.foo.x"), 1 )
         self.assertEqual( s.get( ["nested_dict", "foo", "x"] ), 1 )
         self.assertEqual( s.get("xyzzy.foo", "default"), "default" )

         self.assertEqual( s.get( ["dict_list", 0, "foo"] ), "S" )
         self.assertEqual( s.get( "dict_list.0.foo" ), "S" )

         self.assertEqual( s.get( "dict_list" )[1]["bar"], 6 )
         self.assertEqual( s.get( "dict_list.foo=T.bar" ), 6 )
         self.assertEqual( s.get( [ "dict_list", { "foo": "T" }, "bar" ] ), 6 )

         self.assertEqual( s.get("xyzzy"), None )
         self.assertEqual( s.get("xyzzy", "xyz"), "xyz" )

    def test_find_all(self):
        first = { "foo": "a", "bar": { "x": 1, "y": 0 } }
        second = { "foo": "b", "bar": { "x": 2, "y": 1 } }
        third = { "bar": { "x": 2, "y": None } }

        some_list = [ "something", first, second, HelmData(third), ]

        self.assertEqual( unwrap( find_all({}, some_list) ), [ first, second, third ] )

        self.assertEqual( unwrap( find_all({ "foo": "a" }, some_list) ), [ first ] )
        self.assertIsInstance( find_all({ "foo": "a" }, some_list)[0], HelmData )
        self.assertIsInstance( find_all({ "foo": "a" }, some_list, MyStruct)[0], MyStruct )

        self.assertEqual( unwrap( find_all({ "bar.x": 2 }, some_list) ), [ second, third ] )
        self.assertEqual( unwrap( find_all({ "bar.x": 2, "foo": "a" }, some_list) ), [] )

        self.assertEqual( unwrap( find_all({ "bar.y": DEFINED }, some_list) ), [ first, second, third ] )
        self.assertEqual( unwrap( find_all({ "bar.y": NOT_NONE }, some_list) ), [ first, second ] )
        self.assertEqual( unwrap( find_all({ "bar.y": NOT_EMPTY }, some_list) ), [ second ] )
        self.assertEqual( unwrap( find_all({ "bar.y": None }, some_list) ), [ third ] )
        self.assertEqual( unwrap( find_all({ "bar.y": False }, some_list) ), [] )
        self.assertEqual( unwrap( find_all({ "bar.y": True }, some_list) ), [] )

    def test_find(self):
        first = { "foo": "a", "bar": { "x": 1, "y": 0 } }
        second = { "foo": "b", "bar": { "x": 2, "y": 1 } }
        third = { "bar": { "x": 2, "y": None } }

        some_list = [ "something", first, second, HelmData(third), ]

        self.assertEqual( unwrap( find({}, some_list) ), first )

        self.assertEqual( unwrap( find({ "foo": "a" }, some_list) ), first )
        self.assertIsInstance( find({ "foo": "a" }, some_list), HelmData )
        self.assertIsInstance( find({ "foo": "a" }, some_list, MyStruct), MyStruct )

        self.assertEqual( unwrap( find({ "bar.x": 2 }, some_list) ), second )
        self.assertIsNone( find({ "bar.x": 2, "foo": "a" }, some_list) )

    def test_update(self):
        other = {
            "some_int": 67890,
            "another_string": "ABCD",
            "string_list": [ "x", "y", "z" ],
            "nested_dict": {
                "foo": { "x": 111 },
                "bar": { "y": [] },
                "baz": { "x": 3 },
            },
        }

        s = HelmData(TEST_DATA)
        s.update(other)

        self.assertEqual(s.some_int, 67890)
        self.assertEqual(s.some_string, "abcd")
        self.assertEqual(s.another_string, "ABCD")
        self.assertEqual(s.string_list, [ "x", "y", "z" ])
        self.assertEqual(s.nested_dict.foo.x, 111)
        self.assertEqual(s.nested_dict.foo.y, [ 1, 2, 3 ])
        self.assertEqual(s.nested_dict.bar.x, 2)
        self.assertEqual(s.nested_dict.bar.y, [])
        self.assertEqual(s.nested_dict.baz.x, 3)

        t = HelmData(TEST_DATA)
        t.update( HelmData(other) )

        self.assertEqual(t.values, s.values)

    def test_load_and_dump(self):
        s = HelmData(TEST_DATA)
        t = HelmData()
        t.load_yaml_file( TEST_DIR + "/test_struct_data.yaml" )

        self.assertTrue(t, s)

        dumped = t.dump()
        t2 = HelmData()
        t2.load_yaml_data(dumped)

        self.assertEqual(t2.values, t.values)

    def test_load_bad_yaml(self):
        t = HelmData()

        self.assertRaises(yaml.YAMLError, lambda: t.load_yaml_file( TEST_DIR + "/bad_struct_data.yaml" ) )
