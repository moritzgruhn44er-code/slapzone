import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Text } from 'react-native';
import colors from '../theme/colors';
import HomeScreen from '../screens/HomeScreen';
import DuelScreen from '../screens/DuelScreen';
import MasterMoScreen from '../screens/MasterMoScreen';
import StatsScreen from '../screens/StatsScreen';

const Tab = createBottomTabNavigator();

const TabIcon = ({ label, focused }) => (
  <Text style={{ fontSize: 20 }}>
    {label === 'Spiele' ? '🎮' : label === 'Duell' ? '⚔️' : label === 'Master Mo' ? '🤖' : '📊'}
  </Text>
);

export default function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          height: 80,
          paddingBottom: 12,
          paddingTop: 8,
        },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarLabelStyle: {
          fontSize: 11,
          fontWeight: '600',
          letterSpacing: 0.3,
        },
        tabBarIcon: ({ focused }) => (
          <TabIcon label={route.name} focused={focused} />
        ),
      })}
    >
      <Tab.Screen name=Spiele component={HomeScreen} />
      <Tab.Screen name=Duell component={DuelScreen} />
      <Tab.Screen name=Master Mo component={MasterMoScreen} />
      <Tab.Screen name=Stats component={StatsScreen} />
    </Tab.Navigator>
  );
}
